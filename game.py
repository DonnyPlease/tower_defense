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
        self.state_id = 0   # 0 = start menu 
                            # 1 = choose level
                            # 2 = some chosen level
                            # 3 = paused level
                            # 4 = win/lose level
        self.state = states.get_state(self.state_id)
        self.surface = self.state.get_surface()

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
            self.state.button_group.update(mouse_x, mouse_y)
            self.state.update()
            
            # Draw current frame
            self.state.draw(self.screen)
            pygame.display.update()
            clock.tick(60)
    
    def change_state(self):
        self.state = states.get_state(self.state_id)
        self.surface = self.state.get_surface()
