# generate_faces.py
import os, random, zipfile, io
from diffusers import StableDiffusionXLPipeline
import torch
from PIL import Image

# --- Configuration ---
OUT_DIR = "faces"
WIDTH, HEIGHT = 192, 256
STEPS = 30
GUIDANCE = 5.0
DEVICE = "cuda" if torch.cuda.is_available() else "cpu"
MODEL = "stabilityai/stable-diffusion-xl-base-1.0"  # higher quality than sdxl-turbo (slower but better faces)

# Set a global seed for reproducibility (optional)
random.seed(42)
torch.manual_seed(42)

# Name → attributes (gender, ethnicity/region)
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
    ("Maria Alvarez", "female", "Latina/Hispanic"),
    ("David Okoro", "male", "Black/African diaspora"),
    ("Helen Stein", "female", "European/white"),
    ("Rajesh Mehta", "male", "South Asian"),
    ("Evelyn Thompson", "female", "European/white"),
    ("Kenji Nakamura", "male", "East Asian / Japanese"),
    ("Patricia O’Connor", "female", "European/white"),
    ("Samir Haddad", "male", "Middle Eastern"),
    ("Lucia Moretti", "female", "European/white"),
    ("James Carter", "male", "European/white"),

]

# Helper to build a clean prompt per person
def build_prompt(name, gender, ethnicity, age=None):
    glasses_options = ["wearing glasses", "not wearing glasses", "not wearing glasses"]
    glasses = random.choice(glasses_options)
    if age is None:
        age = random.randint(40, 70)
    # Emphasize studio neutrality and realism; no text in image
    prompt = (
        f"photorealistic studio headshot portrait of a {gender}, "
        f"{ethnicity.lower()}, age {age}, neutral background, soft diffused lighting, "
        f"sharp focus, natural skin texture, looking into camera, no text, somewhat positive expression, "
        f"{glasses}"
    )
    negative = (
        "text, watermark, logo, caption, signature, frame, border, extra fingers, "
        "deformed, blurry, low-res, overprocessed, jpeg artifacts"
    )
    return prompt, negative, age

# --- Load pipeline ---
pipe = StableDiffusionXLPipeline.from_pretrained(
    MODEL, torch_dtype=torch.float16 if DEVICE == "cuda" else torch.float32
)
pipe = pipe.to(DEVICE)

# Slightly stronger CFG for consistency; feel free to tweak GUIDANCE/steps
os.makedirs(OUT_DIR, exist_ok=True)

for (file_name, gender, ethnicity) in people:
    prompt, negative, age = build_prompt(file_name, gender, ethnicity)
    print(f"Generating {file_name} with prompt: {prompt} (age {age}) ethnicity: {ethnicity}")
    image = pipe(
        prompt=prompt,
        negative_prompt=negative,
        num_inference_steps=STEPS,
        guidance_scale=GUIDANCE,
        width=WIDTH, height=HEIGHT,
    ).images[0]

    # Ensure no embedded text: we already discouraged it via negative prompt.
    # Save
    out_path = os.path.join(OUT_DIR, f"{file_name}.png")
    image.save(out_path)

# Zip them all
zip_path = "faces.zip"
with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
    for fname in os.listdir(OUT_DIR):
        if fname.lower().endswith(".png"):
            zf.write(os.path.join(OUT_DIR, fname), arcname=fname)

print(f"Done. Saved 20 images in '{OUT_DIR}/' and archive '{zip_path}'.")
