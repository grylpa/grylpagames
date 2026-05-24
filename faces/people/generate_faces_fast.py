# generate_faces_fixed.py
import os, random, zipfile, math
from PIL import Image
import torch

from diffusers import StableDiffusionXLPipeline, DPMSolverMultistepScheduler

OUT_DIR = "faces"
# Final output size; we will *render larger* then downscale for crisp results
FINAL_W, FINAL_H = 192, 256
RENDER_W, RENDER_H = 768, 1024
STEPS = 8
GUIDANCE = 1.5
DEVICE = "cuda" if torch.cuda.is_available() else "cpu"

# A portrait-tuned XL model (much better for faces than SDXL-base)
MODEL_ID = "stabilityai/sdxl-turbo"
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
]

people = people[:3]

def build_prompt(name, gender, ethnicity, age=None):
    if age is None:
        age = random.randint(40, 70)
    
    glasses_options = [
        "wearing glasses",
        "not wearing glasses",
        "not wearing glasses",
        "wearing subtle rimless glasses",
    ]
    glasses = random.choice(glasses_options)
    
    # Gentle, positive expression (not toothy grin), studio realism
    prompt = (
        f"photorealistic studio headshot, {gender}, {ethnicity.lower()}, age {age}, "
        f"{glasses}, neutral background, soft diffused lighting, shoulder framing, centered, "
        "natural skin texture, gentle pleasant expression, looking into camera, high detail, 85mm lens"
    )
    negative = (
        "painting, abstract, illustration, cartoon, 3d render, text, watermark, logo, caption, "
        "signature, border, extra fingers, deformed, disfigured, blurry, lowres, low quality, "
        "overprocessed, jpeg artifacts, bad anatomy"
    )
    return prompt, negative

# Load model
dtype = torch.float16 if DEVICE == "cuda" else torch.float32
pipe = StableDiffusionXLPipeline.from_pretrained(MODEL_ID, torch_dtype=dtype, variant=None)
pipe.scheduler = DPMSolverMultistepScheduler.from_config(pipe.scheduler.config)
pipe = pipe.to(DEVICE)

# Memory helpers (safe for both CPU & CUDA)
pipe.enable_vae_tiling()
pipe.enable_vae_slicing()
if DEVICE == "cuda":
    pipe.enable_model_cpu_offload()  # ok on low VRAM; remove if you have plenty

os.makedirs(OUT_DIR, exist_ok=True)

for (file_name, gender, ethnicity) in people:
    # Deterministic per-person seed so reruns are stable
    seed = (abs(hash(file_name)) % (2**32 - 1))
    generator = torch.Generator(device=DEVICE).manual_seed(seed)

    prompt, negative = build_prompt(file_name, gender, ethnicity)
    print(f"[+] Generating {file_name} | {gender}, {ethnicity} | seed={seed}")
    img = pipe(
        prompt=prompt,
        negative_prompt=negative,
        num_inference_steps=STEPS,
        guidance_scale=GUIDANCE,
        width=RENDER_W, height=RENDER_H,
        generator=generator,
    ).images[0]

    # Downscale for crisp small output
    img = img.resize((FINAL_W, FINAL_H), Image.LANCZOS)
    img.save(os.path.join(OUT_DIR, f"{file_name}.png"))

# Zip
with zipfile.ZipFile("faces.zip", "w", compression=zipfile.ZIP_DEFLATED) as zf:
    for fn in sorted(os.listdir(OUT_DIR)):
        if fn.lower().endswith(".png"):
            zf.write(os.path.join(OUT_DIR, fn), arcname=fn)

print("Done: wrote", len(os.listdir(OUT_DIR)), "PNGs and faces.zip")
