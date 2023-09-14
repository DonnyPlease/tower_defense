from typing import Any, Iterable, Union
import pygame
from pygame.sprite import AbstractGroup

from resources import T_RES
from game import SQUARE_SIZE
class Button(pygame.sprite.Group):
    def __init__(self):
        super().__init__()
    
    def check_hover(self):
        (x,y) = pygame.mouse.get_pos()
        for button in self.sprites():
            button.check_hover(x, y)
            
    def update(self):
        self.check_hover()
        super().update()

class Button(pygame.sprite.Sprite):
    """Button class

    ...
    
    Attributes
    ----------
    x :
    y :
    type :
    selected :
    hover :
    image_normal :
    image_hover :
    image_pressed :
    image :
    rect :
    """
    def __init__(self, x, y, folder):
        super().__init__()
        self.x = x
        self.y = y
        self.type = folder[:-1]
        self.selected = False
        self.hover = False
        self.image_normal = pygame.image.load(folder+"button.png").convert_alpha()
        self.image_hover = pygame.image.load(folder+"button_hover.png").convert_alpha()
        self.image_pressed = pygame.image.load(folder+"button_pressed.png").convert_alpha()
        self.image = self.image_normal
        self.image.set_colorkey((255, 255, 255))
        self.rect = self.image.get_rect(topleft=(SQUARE_SIZE*self.x, 
                                                 SQUARE_SIZE*self.y))

    def check_hover(self, x, y):
        self.hover = self.rect.collidepoint((x,y))
    
    def click(self):
        """A function that toggles the button.

        ...
        
        Returns
        -------
        string
            selected type
        """
        if self.selected:
            self.selected = False
            return None
        self.selected = True
        return self.type 
        
    def update(self, x, y):
        """An implementation of the function so we can update all the buttons
        at once.

        ...
        
        Parameters
        ----------
        x : int
            index of the column
        y : int
            index of the row
        
        Returns
        -------
        None
        """
        if self.selected:
            self.image = self.image_pressed
            self.image.set_colorkey((255, 255, 255))
            return
        if self.hover:
            self.image = self.image_hover
            self.image.set_colorkey((255, 255, 255))
            return
        self.image = self.image_normal
        self.image.set_colorkey((255, 255, 255))
            
            

            
        
        
        
    
