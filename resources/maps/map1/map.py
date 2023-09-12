from PIL import Image, ImageDraw

# Load the image
image_path = 'resources/maps/map1/map.png'  # Replace 'your_image.png' with the path to your image
image = Image.open(image_path)

# Define the dimensions of the grid
num_rows = 15
num_cols = 20
square_width = image.width // num_cols
square_height = image.height // num_rows

# Initialize a list to store the coordinates of white squares in the middle
white_square_coordinates = []

# Convert the image to grayscale
gray_image = image.convert('L')

# Iterate through the grid and check the center of each square
for row in range(num_rows):
    for col in range(num_cols):
        # Calculate the center coordinates of the current square
        center_x = col * square_width + square_width // 2
        center_y = row * square_height + square_height // 2

        # Check if the center of the square is white (thresholded)
        pixel_color = gray_image.getpixel((center_x, center_y))
        if pixel_color > 200:  # Adjust the threshold value as needed
            white_square_coordinates.append((row, col))

# Print the coordinates of white squares in the middle
for row, col in white_square_coordinates:
    print(f"White square at Row {row}, Column {col}")

# Create a drawing object
draw = ImageDraw.Draw(image)

# Optionally, you can visualize the result by drawing rectangles around the white squares
for row, col in white_square_coordinates:
    x0 = col * square_width
    y0 = row * square_height
    x1 = x0 + square_width
    y1 = y0 + square_height
    draw.rectangle([x0, y0, x1, y1], outline=(0, 255, 0), width=2)

# Save or display the image with rectangles drawn around white squares
# output_path = 'output_image.png'  # Specify the path to save the result
# image.save(output_path)
image.show()

# Save the coordinates to a file
output_file = 'resources/maps/map1/map.txt'  # Specify the output file path
with open(output_file, 'w') as file:
    for row, col in white_square_coordinates:
        file.write(f"{row},{col}\n")

# Optionally, you can close the displayed image after a key press
input("Press any key to close the displayed image and exit.")
