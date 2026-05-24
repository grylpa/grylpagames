# generate_faces_fixed.py
import os, random, zipfile, math
from PIL import Image
import torch

import os
os.environ["HF_HOME"] = "./opt/hf-cache"            # or:
# os.environ["HUGGINGFACE_HUB_CACHE"] = "./opt/hf-cache"

os.environ["PYTORCH_CUDA_ALLOC_CONF"]="expandable_segments:True"

from diffusers import StableDiffusionXLPipeline, DPMSolverMultistepScheduler

CREATE_ZIP = False

OUT_DIR = "faces"
OUT_DIR_RESIZED = "faces/resized"
# Final output size; we will *render larger* then downscale for crisp results
FINAL_W, FINAL_H = 224, 288
RENDER_W, RENDER_H = 896, 1152   # multiples of 64, much better for SDXL
STEPS = 32
GUIDANCE = 7
DEVICE = "cuda" if torch.cuda.is_available() else "cpu"

# A portrait-tuned XL model (much better for faces than SDXL-base)
MODEL_ID = "SG161222/RealVisXL_V5.0_Lightning"  # or "SG161222/RealVisXL_V6.0" if available
# Alternatives: "Lykon/dreamshaper-xl-1-0", "SG161222/RealVisXL_V4.0"

random.seed(42)
torch.manual_seed(42)

people = [
    ("Emma_Harris",        "female", "European/white"),
    ("Barbara_Coleman",    "female", "Black/African diaspora"),
    ("Anand_Iyer",         "male",   "South Asian"),
    ("Carolyn_Ramirez",    "female", "Latina/Hispanic"),
    ("Joe_Hamilton",       "male",   "European/white"),
    ("Naomi_Blake",        "female", "Black/African diaspora"),
    ("Curtis_Scott",       "male",   "Black/African diaspora"),
    ("Farida_Abbasi",      "female", "Middle Eastern / North African"),
    ("Molly_Bishop",       "female", "European/white"),
    ("Takeo_Yamamoto",     "male",   "East Asian / Japanese"),
    ("Beverly_Mitchel",    "female", "European/white"),
    ("Oscar_Vargas",       "male",   "Latino/Hispanic"),
    ("Karl_Schulz",        "male",   "European/white"),
    ("Gladys_Rivera",      "female", "Latina/Hispanic"),
    ("SungWoo_Kim",        "male",   "East Asian / Korean"),
    ("Tanya_Greene",       "female", "European/white"),
    ("Marcia_Wallace",     "female", "European/white"),
    ("Leonard_Hicks",      "male",   "Black/African diaspora"),
    ("Gloria_Navarro",     "female", "Latina/Hispanic"),
    ("Hassan_Odeh",        "male",   "Middle Eastern"),
    ("Maria_Alvarez",      "female", "Latina/Hispanic"),
    ("David_Okoro",        "male",   "Black/African diaspora"),
    ("Helen_Stein",        "female", "European/white"),
    ("Rajesh_Mehta",       "male",   "South Asian"),
    ("Evelyn_Thompson",    "female", "European/white"),
    ("Kenji_Nakamura",     "male",   "East Asian / Japanese"),
    ("Patricia_O_Connor",  "female", "European/white"),
    ("Samir_Haddad",       "male",   "Middle Eastern"),
    ("Lucia_Moretti",      "female", "European/white"),
    ("James_Carter",       "male",   "European/white"),

    ("Nikos Manolaris", "male", "Greek"),
    ("Petros Kalivis", "male", "Greek"),
    ("Stavros Kanelos", "male", "Greek"),
    ("Yannis Drepanos", "male", "Greek"),

    ("Eleni Makri", "female", "Greek"),
    ("Katerina Theodorou", "female", "Greek"),
    ("Sofia Mantzou", "female", "Greek"),
    ("Maria Kyrgiou", "female", "Greek"),

    ("Ivan Korchev", "male", "Russian"),
    ("Dmitri Volodin", "male", "Russian"),
    ("Pavel Serkin", "male", "Russian"),

    ("Natalia Rudnikova", "female", "Russian"),
    ("Irina Koval", "female", "Russian"),
    ("Alina Vetrova", "female", "Russian"),

    ("Erik Lundgren", "male", "Scandinavian"),
    ("Soren Vikström", "male", "Scandinavian"),
    ("Mattias Haugen", "male", "Scandinavian"),

    ("Freja Nyberg", "female", "Scandinavian"),
    ("Linnea Rautio", "female", "Scandinavian"),
    ("Ingrid Holmgaard", "female", "Scandinavian"),
]

HAIR_LEN = ["short hair", "medium-length hair", "long hair"]
HAIR_STYLE = ["straight", "wavy", "curly", "slightly messy", "sleek"]
HAIR_COLOR = ["brown", "black", "blonde", "dark blonde", "salt-and-pepper", "gray"]
EYE_COLOR = ["brown eyes", "hazel eyes", "green eyes", "blue eyes", "dark brown eyes"]
BG = ["neutral light gray background", "soft beige background", "pale warm gray background", "light desaturated blue background"]
WARDROBE = ["casual shirt", "plain tee", "button-up shirt", "light sweater", "blazer over shirt"]
POSE = ["frontal view", "three-quarter view", "slight head tilt", "head turned slightly left", "head turned slightly right"]
LIGHT = ["soft diffused lighting", "classic Rembrandt lighting", "soft butterfly lighting", "soft split lighting"]
LENS = ["35mm lens", "50mm lens", "85mm lens", "105mm lens"]
EXPRESS = ["neutral calm expression", "gentle pleasant expression", "subtle closed-lips smile"]

def build_prompt(name, gender, ethnicity, age=None):
    if age is None:
        age = random.randint(40, 70)
        
    glasses_options = [
        "glasses",
        "wearing subtle rimless glasses",
    ]
    if random.randint(0, 2) == 0:
        glasses = random.choice(glasses_options) + ", "
    else:
        glasses = ""

    if gender == "male" and random.randint(0, 3) == 0:
        beard_options = [
            "light stubble beard",
            "well-groomed short beard",
            "short boxed beard",
            "neatly trimmed beard",
        ]
        glasses += random.choice(beard_options) + ", "
    
    # Gentle, positive expression (not toothy grin), studio realism
    prompt = (
        f"photorealistic studio headshot, {gender}, {ethnicity.lower()}, age {age}, "
        f"{glasses}neutral background, soft diffused lighting, shoulder framing, centered, "
        "natural skin texture, gentle pleasant expression, looking into camera, high detail, 85mm lens, "
    )
    negative = (
        "painting, abstract, illustration, cartoon, 3d render, text, watermark, logo, caption, "
        "signature, border, extra fingers, deformed, disfigured, blurry, lowres, low quality, "
        "overprocessed, jpeg artifacts, bad anatomy, hijabs, kaffiyeh, undershirt, headwear"
    )
    return prompt, negative

# Load model
dtype = torch.float16 if DEVICE == "cuda" else torch.float32
# pipe = StableDiffusionXLPipeline.from_pretrained(MODEL_ID, torch_dtype=dtype, variant=None)

# pipe = StableDiffusionXLPipeline.from_pretrained(
#     "SG161222/RealVisXL_V5.0_Lightning",
#     cache_dir="/opt/hf-cache",
#     torch_dtype=dtype
# )

pipe = StableDiffusionXLPipeline.from_pretrained(
    "./opt/hf-cache/models--SG161222--RealVisXL_V5.0_Lightning/snapshots/f4454158cedaab9f0688c199561d6c92525f3a85",
    local_files_only=True,
    torch_dtype=dtype
)

pipe.scheduler = DPMSolverMultistepScheduler.from_config(pipe.scheduler.config)
pipe = pipe.to(DEVICE)

# Memory helpers (safe for both CPU & CUDA)
pipe.enable_vae_tiling()
pipe.enable_vae_slicing()
if DEVICE == "cuda":
    pipe.enable_model_cpu_offload()  # ok on low VRAM; remove if you have plenty

os.makedirs(OUT_DIR, exist_ok=True)
os.makedirs(OUT_DIR_RESIZED, exist_ok=True)

for i,(file_name, gender, ethnicity) in enumerate(people):
    # Deterministic per-person seed so reruns are stable
    seed = (abs(hash(file_name)) % (2**32 - 1))
    generator = torch.Generator(device=DEVICE).manual_seed(seed)

    prompt, negative = build_prompt(file_name, gender, ethnicity)
    print(f"Generating {i+1:>2d}/{len(people)} {file_name} | {gender}, {ethnicity}")
    img = pipe(
        prompt=prompt,
        negative_prompt=negative,
        num_inference_steps=STEPS,
        guidance_scale=GUIDANCE,
        width=RENDER_W, height=RENDER_H,
        generator=generator,
    ).images[0]

    img.save(os.path.join(OUT_DIR, f"{file_name}.jpg"), quality=90)
    img = img.resize((FINAL_W, FINAL_H), Image.LANCZOS)
    img.save(os.path.join(OUT_DIR_RESIZED, f"{file_name}.jpg"), quality=90)

if CREATE_ZIP:
    with zipfile.ZipFile("faces.zip", "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for fn in sorted(os.listdir(OUT_DIR)):
            if fn.lower().endswith(".jpg"):
                zf.write(os.path.join(OUT_DIR, fn), arcname=fn)

print("Done: wrote", len(os.listdir(OUT_DIR)), "JPGs and faces.zip")
