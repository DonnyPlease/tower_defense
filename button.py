import pygame

from resources import T_RES
from game import SQUARE_SIZE

class Button(pygame.sprite.Sprite):
    def __init__(self, x, y, path):
        super().__init__()
        self.x = x
        self.y = y
        self.type = path[:-1]
        self.selected = False
        self.hover = True
        self.image_normal = pygame.image.load(T_RES+path+"button.png").convert_alpha()
        self.image_hover = pygame.image.load(T_RES+path+"button_hover.png").convert_alpha()
        self.image_pressed = pygame.image.load(T_RES+path+"button_pressed.png").convert_alpha()
        self.image = self.image_normal
        self.image.set_colorkey((255, 255, 255))
        self.rect = self.image.get_rect(topleft=(SQUARE_SIZE*self.x, SQUARE_SIZE*self.y))

    def click(self):
        if self.selected:
            self.selected = False
            return None
        self.selected = True
        return self.type 
        
    def update(self, x, y):
        if self.selected:
            self.image = self.image_pressed
            self.image.set_colorkey((255, 255, 255))
            return
        if (x==self.x) and (y==self.y):
            self.image = self.image_hover
            self.image.set_colorkey((255, 255, 255))
            return
        self.image = self.image_normal
        self.image.set_colorkey((255, 255, 255))
            
            

            
        
        
        
    
