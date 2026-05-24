from pathlib import Path
from PIL import Image

# Hardcoded input frames
INPUT_FILES = [
	"../art/worm_0.png",
	"../art/worm_1.png",
	"../art/worm_2.png",
	"../art/worm_3.png",
	"../art/worm_4.png",
]

OUTPUT_DIR = Path("../art")
OUTPUT_DIR.mkdir(exist_ok=True)

def cyclic_shift_left(img, shift_px):
	w, h = img.size
	shift_px %= w
	if shift_px == 0:
		return img.copy()

	left = img.crop((0, 0, shift_px, h))
	right = img.crop((shift_px, 0, w, h))

	out = Image.new(img.mode, (w, h))
	out.paste(right, (0, 0))
	out.paste(left, (w - shift_px, 0))
	return out

def main():
	n = len(INPUT_FILES)
	images = [Image.open(p).convert("RGBA") for p in INPUT_FILES]

	w, h = images[0].size

	# equal step size
	step = w // n  # integer-safe (good for pixel art)

	for i, img in enumerate(images):
		shift_px = i * step   # 0, X, 2X, ...
		shifted = cyclic_shift_left(img, shift_px)

		out_name = Path(INPUT_FILES[i]).stem + f"_shifted_{i:02d}.png"
		out_path = OUTPUT_DIR / out_name
		shifted.save(out_path)
		print(f"{out_path}  shift={shift_px}px")

if __name__ == "__main__":
	main()