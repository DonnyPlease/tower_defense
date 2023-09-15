import queue
from resources import M_RES

class Game_map():
    def __init__(self, level_number) -> None:
        self.map_path = load_path(M_RES + 'map{}/map.txt'.format(level_number))
        self.map_end = load_path(M_RES + 'map{}/end.txt'.format(level_number))
        self.map_start = load_path(M_RES + 'map{}/start.txt'.format(level_number))

def load_path(path):
    map_path = []
    with open(path,'r') as file:
        for line in file:
            y, x = map(int, line.strip().split(','))
            map_path.append((x,y))
    return map_path

def find_shortest_path(path, start, end):
    
    graph = {}
    for coord1 in path:
        adjacent_nodes = [coord2 for coord2 in path if is_adjacent(coord1, coord2)]
        graph[coord1] = adjacent_nodes
    
    visited = set()
    path = {}
    q = queue.Queue()
    q.put(start)
    visited.add(start)
    
    while not q.empty():
        current_node = q.get()
        if current_node == end:
            break
        for neighbor in graph[current_node]:
            if neighbor not in visited:
                visited.add(neighbor)
                path[neighbor] = current_node
                q.put(neighbor)
                
    shortest_path = []
    current_node = end
    while current_node != start:
        shortest_path.append(current_node)
        current_node = path[current_node]
    shortest_path.append(start)
    shortest_path.reverse()
    
    return shortest_path    
    
def no_path(path, start, end):
    return len(find_shortest_path(path,start,end)) == 0
        
    
def is_adjacent(coord1, coord2):
    x1, y1 = coord1
    x2, y2 = coord2
    return abs(x1-x2) + abs(y1-y2) == 1


       
    
    