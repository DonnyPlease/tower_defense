import pygame

from resources import T_RES
from game import SQUARE_SIZE

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
        self.hover = True
        self.image_normal = pygame.image.load(T_RES+folder+"button.png").convert_alpha()
        self.image_hover = pygame.image.load(T_RES+folder+"button_hover.png").convert_alpha()
        self.image_pressed = pygame.image.load(T_RES+folder+"button_pressed.png").convert_alpha()
        self.image = self.image_normal
        self.image.set_colorkey((255, 255, 255))
        self.rect = self.image.get_rect(topleft=(SQUARE_SIZE*self.x, 
                                                 SQUARE_SIZE*self.y))

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
        if (x==self.x) and (y==self.y):
            self.image = self.image_hover
            self.image.set_colorkey((255, 255, 255))
            return
        self.image = self.image_normal
        self.image.set_colorkey((255, 255, 255))
            
            

            
        
        
        
    
