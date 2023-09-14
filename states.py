from abc import abstractmethod
import pygame
import button
from resources import MENU_RES, T_RES


class State:
    def __init__(self):
        pass
    
    def get_surface(self):
        return self.surface
    
    @abstractmethod
    def is_level(self):
        pass
    
    @abstractmethod
    def is_menu(self):
        pass
    
    @abstractmethod
    def get_buttons(self):
        pass
    


class Menu(State):
    def __init__(self) -> None:
        super().__init__()
        self.surface = pygame.Surface((1000,600))
        self.surface.fill((255,255,255))
    
    def is_menu(self):
        return True

    def is_level(self):
        return False
    
    def get_buttons(self):
        button_group = pygame.sprite.Group()
        start_button = button.Button(10,5,MENU_RES+'start_button/')
        quit_button = button.Button(10,8,MENU_RES+'quit_button/')
        
        button_group.add(start_button)
        button_group.add(quit_button)
        
        return button_group
    
class Level(State):
    def __init__(self, level_number):
        super().__init__()
        
    def is_menu(self):
        return False
    
    def is_level(self):
        return True
    
    def get_buttons(self):
        button_group = pygame.sprite.Group()
        
        button_tower1 = button.Button(22, 2, T_RES+'tower1/')
        button_tower2 = button.Button(22, 4, T_RES+'tower2/')
        
        button_group.add(button_tower1)
        button_group.add(button_tower2)
        
        return button_group
    
        
    
def get_state(ids : int) -> State:
    if ids == 0:
        return Menu()
    if ids == 1:
        return Level(1)