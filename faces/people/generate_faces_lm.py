# generate_faces_fixed.py
import os, random, zipfile, math
from PIL import Image
import torch

import os
CACHE_DIR = "./opt/hf-cache"
os.environ["HF_HOME"] = CACHE_DIR            # or:
# os.environ["HUGGINGFACE_HUB_CACHE"] = CACHE_DIR

os.environ["PYTORCH_CUDA_ALLOC_CONF"]="expandable_segments:True"

from diffusers import StableDiffusionXLPipeline, DPMSolverMultistepScheduler, EulerAncestralDiscreteScheduler, StableDiffusionPipeline

OUT_DIR = "faces"
# Final output size; we will *render larger* then downscale for crisp results
FINAL_W, FINAL_H = 192, 256
RENDER_W, RENDER_H = 512, 704
STEPS = 22
GUIDANCE = 7
DEVICE = "cuda" if torch.cuda.is_available() else "cpu"

MODEL = "Lykon/dreamshaper-7"             # pick one from the list above
VAE   = "stabilityai/sd-vae-ft-mse"       # optional but recommended


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
# pipe = StableDiffusionXLPipeline.from_pretrained(MODEL_ID, torch_dtype=dtype, variant=None)

# pipe = StableDiffusionXLPipeline.from_pretrained(
#     "SG161222/RealVisXL_V5.0_Lightning",
#     cache_dir=CACHE_DIR,
#     torch_dtype=dtype
# )

pipe = StableDiffusionPipeline.from_pretrained(MODEL, torch_dtype=dtype, cache_dir=CACHE_DIR)

# pipe = StableDiffusionPipeline.from_pretrained(
#     "./opt/hf-cache/models--Lykon--dreamshaper-7/snapshots/9b481047f77996efa025e75e03941dbf51f506ad",
#     local_files_only=True,
#     dtype=dtype
# )

pipe.scheduler = EulerAncestralDiscreteScheduler.from_config(pipe.scheduler.config)
if VAE:
    pipe.vae = pipe.vae.from_pretrained(VAE, torch_dtype=dtype, cache_dir=CACHE_DIR)
# Low-VRAM tricks
pipe.enable_attention_slicing()
pipe.enable_vae_slicing()
pipe.enable_vae_tiling()
if DEVICE == "cuda":
    pipe.enable_model_cpu_offload()  # fits 6–8GB GPUs easily

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
    print(f"Generating {file_name} | {gender}, {ethnicity}")
    img = pipe(
        prompt=prompt,
        negative_prompt=negative,
        num_inference_steps=STEPS,
        guidance_scale=GUIDANCE,
        width=RENDER_W, height=RENDER_H,
        generator=generator,
    ).images[0]

    # Downscale for crisp small output
    # img = img.resize((FINAL_W, FINAL_H), Image.LANCZOS)
    img.save(os.path.join(OUT_DIR, f"{file_name}.jpg"), quality=95)

# Zip
with zipfile.ZipFile("faces.zip", "w", compression=zipfile.ZIP_DEFLATED) as zf:
    for fn in sorted(os.listdir(OUT_DIR)):
        if fn.lower().endswith(".jpg"):
            zf.write(os.path.join(OUT_DIR, fn), arcname=fn)

print("Done: wrote", len(os.listdir(OUT_DIR)), "JPGs and faces.zip")
