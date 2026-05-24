from pathlib import Path
from PIL import Image

INPUT_FILES = [
	"../art/worm_0.png",
	"../art/worm_1.png",
	"../art/worm_2.png",
	"../art/worm_3.png",
	"../art/worm_4.png",
]

OUTPUT_DIR = Path("../art")
OUTPUT_DIR.mkdir(exist_ok=True)

STRIP_MULTIPLIER = 6   # final temporary strip width = STRIP_MULTIPLIER * W
GAP_PX = 128           # transparent gap between repeated copies

def build_repeated_strip(img: Image.Image, strip_w: int, gap_px: int) -> Image.Image:
	w, h = img.size
	period = w + gap_px

	strip = Image.new("RGBA", (strip_w, h), (0, 0, 0, 0))

	x = 0
	while x < strip_w:
		strip.paste(img, (x, 0))
		x += period

	return strip

def cyclic_shift_left(strip: Image.Image, shift_px: int) -> Image.Image:
	w, h = strip.size
	shift_px %= w
	if shift_px == 0:
		return strip.copy()

	left = strip.crop((0, 0, shift_px, h))
	right = strip.crop((shift_px, 0, w, h))

	out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	out.paste(right, (0, 0))
	out.paste(left, (w - shift_px, 0))
	return out

def main():
	n = len(INPUT_FILES)
	if n == 0:
		raise ValueError("No input files")

	images = [Image.open(p).convert("RGBA") for p in INPUT_FILES]

	w, h = images[0].size
	for i, img in enumerate(images):
		if img.size != (w, h):
			raise ValueError(f"Frame {i} size {img.size} does not match first frame {(w, h)}")

	strip_w = STRIP_MULTIPLIER * w

	# Equal step between animation frames.
	# This gives 0, X, 2X, ...
	step = (w + GAP_PX) // n

	for i, img in enumerate(images):
		strip = build_repeated_strip(img, strip_w, GAP_PX)

		shift_px = i * step
		shifted_strip = cyclic_shift_left(strip, shift_px)

		crop_w = int(w * 1.5)
		# Crop the exact central WxH region
		crop_x = (strip_w - crop_w) // 2
		out = shifted_strip.crop((crop_x, 0, crop_x + crop_w, h))

		out_name = Path(INPUT_FILES[i]).stem + f"_shifted_{i:02d}.png"
		out_path = OUTPUT_DIR / out_name
		out.save(out_path)

		print(f"{out_path}  shift={shift_px}px  step={step}px  gap={GAP_PX}px")

if __name__ == "__main__":
	main()