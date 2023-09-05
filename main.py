import pygame
from sys import exit

if __name__ == '__main__':
    pygame.init() 
    screen = pygame.display.set_mode((800,400))
    while True:
        # Draw all and update everything
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                exit()
        pygame.display.update()