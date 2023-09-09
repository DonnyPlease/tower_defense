import pygame

from resources import T_RES
from game import SQUARE_SIZE

class Button(pygame.sprite.Sprite):
    def __init__(self, x, y, path):
        super().__init__()
        self.x = x
        self.y = y
        self.type = 'tower_1'
        self.selected = False
        self.image = pygame.image.load(T_RES+path+"0.png").convert_alpha()
        self.image.set_colorkey((255, 255, 255))
        self.rect = self.image.get_rect(topleft=(SQUARE_SIZE*self.x, SQUARE_SIZE*self.y))

    def click(self):
        if self.selected:
            self.selected = False
            return
        self.selected = True
        print(self.typ)

            
        
        
        
    
