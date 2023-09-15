import pygame
from sys import exit
from math import pi
from resources import M_RES, T_RES

BG_RES = 'resources/backgrounds/'
SQUARE_SIZE = 40
ROWS = 10
COLUMNS = 15

import tower
import enemy
import bullet
import button
import states

class Game():
    def __init__(self) -> None:
        pygame.init() 
        self.screen = pygame.display.set_mode((1000, 600))
        pygame.display.set_caption('Tower Defense')
        clock = pygame.time.Clock()
        self.state_id = 0    # 0 = start menu 
                        # 1 = choose level
                        # 2 = some chosen level
                        # 3 = paused level
                        # 4 = win/lose level
        self.state = states.get_state(self.state_id)
        
        # test_surface = pygame.image.load(M_RES + '/map1/map.png')
        self.surface = self.state.get_surface()
        self.button_group = self.state.get_buttons()
        
        # Initialize empty groups
        self.tower_group = tower.TowerGroup()
        self.bullet_group = pygame.sprite.Group()
        self.enemy_group = pygame.sprite.Group()
        
        while True:
            mouse_x, mouse_y = pygame.mouse.get_pos()   # Get mouse position
            
            # Set up how to quit game
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    pygame.quit()
                    exit()
                
                # Activate the events based on which state the game is in
                self.state.evaluate_events(event, mouse_x, mouse_y)
                
                # Check whether some event changed the state of the game
                if self.state.change_state:
                    self.state_id = self.state.next_state
                    self.change_state()
            
            
            self.screen.blit(self.surface,(0,0))
            self.button_group.update(mouse_x, mouse_y)
            
            # Evaluate 
            if self.state.is_level():
                self.bullet_group = self.state.bullet_group
                self.enemy_group = self.state.enemy_group
                self.enemy_group.update()
                self.tower_group = self.state.tower_group
                self.tower_group.aim(self.enemy_group)
                self.tower_group.shoot(self.bullet_group)
                self.bullet_group.update()
                self.tower_group.update()
                self.hits = pygame.sprite.groupcollide(self.bullet_group,
                                                   self.enemy_group, 
                                                   True, 
                                                   False)
                self.evaluate_hits()

            
            # Draw current frame
            self.draw()
            pygame.display.update()
            clock.tick(60)
    
    def change_state(self):
        self.state = states.get_state(self.state_id)
        self.button_group = self.state.get_buttons()
        self.surface = self.state.get_surface()
         
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
        
    def draw(self):
        self.bullet_group.draw(self.screen)
        self.tower_group.draw(self.screen)
        self.enemy_group.draw(self.screen)
        self.button_group.draw(self.screen)
        