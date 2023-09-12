import queue
from PIL import Image, ImageDraw

# Load the coordinates from the text file
coordinates_file = 'resources/maps/map1/map.txt'  # Specify the path to the coordinates file
white_square_coordinates = []

with open(coordinates_file, 'r') as file:
    for line in file:
        col, row = map(int, line.strip().split(','))
        white_square_coordinates.append((col, row))

# Function to check if two coordinates are adjacent
def is_adjacent(coord1, coord2):
    row1, col1 = coord1
    row2, col2 = coord2
    return abs(row1 - row2) + abs(col1 - col2) == 1

# Find the start and end points (leftmost and rightmost topmost white squares)
start_point = min(white_square_coordinates, key=lambda x: (x[1], x[0]))
end_point = max(white_square_coordinates, key=lambda x: (x[1], -x[0]))

# Create a graph representation using an adjacency list
graph = {}
for coord1 in white_square_coordinates:
    adjacent_nodes = [coord2 for coord2 in white_square_coordinates if is_adjacent(coord1, coord2)]
    graph[coord1] = adjacent_nodes

# Perform Breadth-First Search to find the shortest path
visited = set()
path = {}
q = queue.Queue()
q.put(start_point)
visited.add(start_point)

while not q.empty():
    current_node = q.get()
    if current_node == end_point:
        break
    for neighbor in graph[current_node]:
        if neighbor not in visited:
            visited.add(neighbor)
            path[neighbor] = current_node
            q.put(neighbor)

# Reconstruct the path from end to start
shortest_path = []
current_node = end_point
while current_node != start_point:
    shortest_path.append(current_node)
    current_node = path[current_node]
shortest_path.append(start_point)
shortest_path.reverse()

# Create an image to draw the solution
image = Image.new('RGB', (800, 600), (255, 255, 255))
draw = ImageDraw.Draw(image)
square_width  = 40
square_height = 40
print(shortest_path)

# Draw the shortest path on the image
for i in range(len(shortest_path) - 1):
    y1, x1 = shortest_path[i]
    y2, x2 = shortest_path[i + 1]
    x1_pixel = x1 * square_width + square_width // 2
    y1_pixel = y1 * square_height + square_height // 2
    x2_pixel = x2 * square_width + square_width // 2
    y2_pixel = y2 * square_height + square_height // 2
    draw.line([(x1_pixel, y1_pixel), (x2_pixel, y2_pixel)], fill=(255, 0, 0), width=2)

# Save or display the image with the shortest path
output_path = 'shortest_path_image.png'  # Specify the path to save the result
image.save(output_path)
image.show()

# Optionally, you can close the displayed image after a key press
input("Press any key to close the displayed image and exit.")
