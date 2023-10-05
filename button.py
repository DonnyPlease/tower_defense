from typing import Any, Iterable, Union
import pygame
from pygame.sprite import AbstractGroup

from resources import T_RES
from game import SQUARE_SIZE
from tower import Tower1, Tower2

class ButtonGroup(pygame.sprite.Group):
    def __init__(self) -> None:
        super().__init__()
    
    def unselect_all(self):
        for button in self.sprites():
            button.unselect()

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
        
    
    def toggle_selected(self):
        """A function that toggles the button.

        ...
        
        Returns
        -------
        bool
            return the state of the button before clicking
        """
        self.selected = not self.selected
        return not self.selected
    
    def unselect(self):
        self.selected = False
        
    def select(self):
        self.selected = True
        
    def update(self, x, y):
        """An implementation of the function so we can update all the buttons
        at once.

        ...
        
        Parameters
        ----------
        x : float
            mouse coordinate x
        y : float
            mouse coordinate y
        
        Returns
        -------
        None
        """
        self.check_hover(x, y)
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
        
class ButtonT1(Button):
    def __init__(self,col,row,folder):
        super().__init__(col,row,folder)
        
    def create_tower(self,col,row):
        return Tower1(col, row)

class ButtonT2(Button):
    def __init__(self,col,row,folder):
        super().__init__(col,row,folder)
        
    def create_tower(self,col,row):
        return Tower2(col, row)
    
class ButtonSell(Button):
    def __init__(self,col,row,folder):
        super().__init__(col,row,folder)
        
    def draw_sell(self,col,row):
        return  
