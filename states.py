from abc import abstractmethod
import sys
from copy import deepcopy
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
    def update(self):
        pass 
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
    def evaluate_events(self, event, mouse_x, mouse_y):
        pass
    

class Menu(State):
    def __init__(self) -> None:
        super().__init__()
        self.surface = pygame.Surface((1000, 600))
        self.surface.fill((255, 255, 255))
        self.start_button = None
        self.quit_button = None
        self.change_state = False
        self.next_state = 1
        self.button_group = pygame.sprite.Group()
        self.set_buttons()
         
    def is_menu(self):
        return True

    def is_level(self):
        return False
    
    def set_buttons(self):
        self.start_button = button.Button(10, 5, MENU_RES+'start_button/')
        self.quit_button = button.Button(10, 8, MENU_RES+'quit_button/')
        
        self.button_group.add(self.start_button)
        self.button_group.add(self.quit_button)
    
    def evaluate_events(self, event, mouse_x, mouse_y):
        if event.type == pygame.MOUSEBUTTONDOWN:
            if self.start_button.hover:
                self.change_state = True
                
            if self.quit_button.hover:
                sys.exit()
                print("DUDE")
    
    def update(self):
        return
    
    def draw(self, screen):
        self.button_group.draw(screen)

        
class Level(State):
    def __init__(self, level_number):
        super().__init__()
        self.surface = pygame.image.load(M_RES+'map{}/map.png'.format(level_number)) 
        self.next_state = 1
        self.paused = False
        self.tower_group = tower.TowerGroup()
        self.enemy_group = enemy.EnemyGroup()
        self.bullet_group = pygame.sprite.Group()
        self.button_group = button.ButtonGroup()
        self.hover_group = pygame.sprite.Group()
        self.game_map = map_path.Game_map(level_number)
        self.tower_group.banned_squares = deepcopy(self.game_map.map_path)
        self.paused_button = button.Button(7.5, 4, 'resources/paused/paused_text/')
        self.to_menu_button = button.Button(7.5, 7, 'resources/paused/back_to_menu/')
        self.set_buttons()
    
    def update(self):
        if self.paused: return
        self.enemy_group.update()
        self.tower_group.aim(self.enemy_group)
        self.tower_group.shoot(self.bullet_group)
        self.bullet_group.update()
        self.tower_group.update()
        self.hits = pygame.sprite.groupcollide(self.bullet_group,
                                               self.enemy_group, 
                                               True, 
                                               False)
        self.evaluate_hits()
    
    def draw(self, screen):
        self.bullet_group.draw(screen)
        self.tower_group.draw(screen)
        self.enemy_group.draw(screen)
        self.button_group.draw(screen)
        self.hover_group.draw(screen)
    
    def is_menu(self):
        return False
    
    def is_level(self):
        return True
    
    def set_buttons(self):
        # Create buttons for towers
        self.button_tower1 = button.Button(22, 2, T_RES+'tower1/')
        self.button_tower2 = button.Button(22, 4, T_RES+'tower2/')
        # Add the buttons to the button group
        self.button_group.add(self.button_tower1)
        self.button_group.add(self.button_tower2)
        
    def toggle_paused_buttons(self):
        if self.paused:
            self.button_group.add(self.paused_button)
            self.button_group.add(self.to_menu_button)
        else:
            self.paused_button.kill()
            self.to_menu_button.kill()
    
    def hover_tower_placement(self, row, col):
        self.hover_group.empty()
        if (col, row) in self.tower_group.banned_squares: return
        
        if self.button_tower1.selected:
            hover_tower = tower.Tower1(col, row)
            self.hover_group.add(hover_tower)
        elif self.button_tower2.selected:
            hover_tower = tower.Tower2(col, row)
            self.hover_group.add(hover_tower)
            
    def tower_button_click(self, butt : button.Button):
        if butt.selected:
            butt.unselect()
            return
        self.button_group.unselect_all()
        butt.select()    
    
    def button_click(self):
        for butt in self.button_group.sprites():
            if butt.hover:
                self.tower_button_click(butt)
                return True
        return False
    
    def evaluate_events(self, event, mouse_x, mouse_y):
        if event.type == pygame.MOUSEBUTTONDOWN:
            if self.paused:
                if self.to_menu_button.hover:
                    self.next_state = 0
                    self.change_state = True
                
            elif self.button_click():
                pass
                
            elif (0<=mouse_x<800) and (0<=mouse_y<600):
                row = mouse_y // 40
                col = mouse_x // 40
                if (col,row) in self.tower_group.banned_squares:
                    pass
                elif self.button_tower1.selected:
                    new_tower = tower.Tower1(col, row)
                    self.tower_group.banned_squares.append((col,row))
                    self.tower_group.add(new_tower)
                elif self.button_tower2.selected:
                    new_tower = tower.Tower2(col, row)
                    self.tower_group.banned_squares.append((col,row))
                    self.tower_group.add(new_tower)
        else:
            if (0<=mouse_x<800) and (0<=mouse_y<600):
                row = mouse_y // 40
                col = mouse_x // 40
                self.hover_tower_placement(row, col)
            
        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_SPACE:
                new_enemy = enemy.Enemy1(self.game_map)
                self.enemy_group.add(new_enemy)  
            elif event.key == pygame.K_ESCAPE:
                self.paused = not self.paused
                self.toggle_paused_buttons()
            
    def evaluate_hits(self):
        for bullet in self.hits:
            if bullet.bullet_type == "normal":
                self.hits[bullet][0].hit(bullet.damage)
            elif bullet.bullet_type == "bomb":
                pass
            elif bullet.bullet_typ == 'misile':
                pass
            elif bullet.bullet_type == "laser":
                pass
        
def get_state(ids : int) -> State:
    if ids == 0:
        return Menu()
    if ids == 1:
        return Level(1)