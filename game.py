import pygame
from sys import exit
from math import pi
from resources import M_RES

BG_RES = 'resources/backgrounds/'
SQUARE_SIZE = 40
ROWS = 10
COLUMNS = 15

import tower
import enemy
import bullet
import button

def load_path(path):
    map_path = []
    with open(path,'r') as file:
        for line in file:
            y, x = map(int, line.strip().split(','))
            map_path.append((x,y))
    return map_path

class Game():
    def __init__(self) -> None:
        pygame.init() 
        screen = pygame.display.set_mode((1000,600))
        pygame.display.set_caption('Tower Defense')
        clock = pygame.time.Clock()
        
        test_surface = pygame.image.load(M_RES + '/map1/map.png')
        self.map_path = load_path(M_RES + '/map1/map.txt')
        self.map_end = load_path(M_RES + '/map1/end.txt')
        self.map_start = load_path(M_RES + '/map1/start.txt')
        
        # tower_group = pygame.sprite.Group()
        tower_group = tower.TowerGroup()
        bullet_group = pygame.sprite.Group()
        enemy_group = pygame.sprite.Group()
        button_group = pygame.sprite.Group()
        
        test_tower = tower.Tower1(14,10)
        tower_group.add(test_tower)
        
        test_enemy = enemy.Enemy1(self)
        enemy_group.add(test_enemy)
        
        button_tower1 = button.Button(22,2,'tower1/')
        button_group.add(button_tower1)
        button_tower2 = button.Button(22,4,'tower2/')
        button_group.add(button_tower2)
        
        chosen = None
        
        while True:
            # Draw all and update everything
                
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    pygame.quit()
                    exit()
                
                if event.type == pygame.MOUSEBUTTONDOWN:
                    (x,y) = event.pos
                    x = x // SQUARE_SIZE
                    y = y // SQUARE_SIZE
                    if (0<=x<20) and (0<=y<15):
                        if chosen == 'tower1':
                            new_tower = tower.Tower1(x,y)
                            tower_group.add(new_tower)
                        if chosen == 'tower2':
                            new_tower = tower.Tower2(x,y)
                            tower_group.add(new_tower)
                            
                    if (x==22) and (y==2):
                        button_tower2.selected = False
                        chosen = button_tower1.click()
                    if (x==22) and (y==4):
                        button_tower1.selected = False
                        chosen = button_tower2.click()    
                        
                
                if event.type == pygame.KEYDOWN:
                    if event.key == pygame.K_SPACE:
                        new_enemy = enemy.Enemy1(self)
                        enemy_group.add(new_enemy)
                    
            screen.blit(test_surface,(0,0))
            
            enemy_group.update()
            
            tower_group.aim(enemy_group)
            tower_group.shoot(bullet_group)
            
            bullet_group.update()
            tower_group.update()
            
            mouse_x, mouse_y = pygame.mouse.get_pos()
            button_group.update(mouse_x//SQUARE_SIZE,mouse_y//SQUARE_SIZE)
            
    
            
            bullet_group.draw(screen)
            tower_group.draw(screen)
            enemy_group.draw(screen)
            button_group.draw(screen)
            
            self.hits = pygame.sprite.groupcollide(bullet_group,
                                                   enemy_group, 
                                                   True, 
                                                   False)
            self.evaluate_hits()
            
            pygame.display.update()
            clock.tick(60)
            
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
        