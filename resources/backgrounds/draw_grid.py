from PIL import Image, ImageDraw

# Constants
GRID_WIDTH = 20
GRID_HEIGHT = 15
SQUARE_SIZE = 40
GRID_COLOR = (255, 255, 255)  # White
OUTPUT_FILENAME = "resources/backgrounds/grid.png"

# Calculate image size
image_width = GRID_WIDTH * SQUARE_SIZE
image_height = GRID_HEIGHT * SQUARE_SIZE

# Create a new blank image
image = Image.new("RGB", (image_width, image_height), color=GRID_COLOR)

# Create a drawing context
draw = ImageDraw.Draw(image)

# Draw the grid of squares
for x in range(GRID_WIDTH):
    for y in range(GRID_HEIGHT):
        left = x * SQUARE_SIZE
        top = y * SQUARE_SIZE
        right = left + SQUARE_SIZE
        bottom = top + SQUARE_SIZE
        draw.rectangle([left, top, right, bottom], outline=(0, 0, 0))  # Black border

# Save the image
image.save(OUTPUT_FILENAME)

print(f"Grid saved as {OUTPUT_FILENAME}")
