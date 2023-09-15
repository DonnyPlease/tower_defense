from abc import abstractmethod
import sys
import pygame
import button
import tower
import enemy
import map_path
from resources import MENU_RES, T_RES, M_RES


class State:
    def __init__(self):
        self.change_state = False
    
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
    
    @abstractmethod
    def evaluate_events(self,event,mouse_x,mouse_y):
        pass
    

class Menu(State):
    def __init__(self) -> None:
        super().__init__()
        self.surface = pygame.Surface((1000,600))
        self.surface.fill((255,255,255))
        self.start_button = None
        self.quit_button = None
        self.change_state = False
        self.next_state = 1
    
    def is_menu(self):
        return True

    def is_level(self):
        return False
    
    def get_buttons(self):
        button_group = pygame.sprite.Group()
        self.start_button = button.Button(10,5,MENU_RES+'start_button/')
        self.quit_button = button.Button(10,8,MENU_RES+'quit_button/')
        
        button_group.add(self.start_button)
        button_group.add(self.quit_button)
        
        return button_group
    
    def evaluate_events(self, event, mouse_x, mouse_y):
        if event.type == pygame.MOUSEBUTTONDOWN:
            if self.start_button.hover:
                self.change_state = True
                
            if self.quit_button.hover:
                sys.exit()
                print("DUDE")
            
        
class Level(State):
    def __init__(self, level_number):
        super().__init__()
        self.surface = pygame.image.load(M_RES + 'map{}/map.png'.format(level_number)) 
        self.next_state = 1
        self.tower_group = tower.TowerGroup()
        self.enemy_group = pygame.sprite.Group()
        self.bullet_group = pygame.sprite.Group()
        self.game_map = map_path.Game_map(level_number)
    
    
    def is_menu(self):
        return False
    
    def is_level(self):
        return True
    
    def get_buttons(self):
        button_group = pygame.sprite.Group()
        
        self.button_tower1 = button.Button(22, 2, T_RES+'tower1/')
        self.button_tower2 = button.Button(22, 4, T_RES+'tower2/')
        
        button_group.add(self.button_tower1)
        button_group.add(self.button_tower2)
        
        return button_group
    
    def evaluate_events(self, event, mouse_x, mouse_y):
        if event.type == pygame.MOUSEBUTTONDOWN:
            if self.button_tower1.hover:
                self.button_tower1.click()
            if self.button_tower2.hover:
                self.button_tower2.click()
            if (0<=mouse_x<800) and (0<=mouse_y<600):
                if self.button_tower1.selected:
                    new_tower = tower.Tower1(mouse_x//40,mouse_y//40)
                    self.tower_group.add(new_tower)
                if self.button_tower2.selected:
                    new_tower = tower.Tower2(mouse_x//40,mouse_y//40)
                    self.tower_group.add(new_tower)
        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_SPACE:
                new_enemy = enemy.Enemy1(self.game_map)
                self.enemy_group.add(new_enemy)
            
        
def get_state(ids : int) -> State:
    if ids == 0:
        return Menu()
    if ids == 1:
        return Level(1)