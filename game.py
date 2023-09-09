import pygame
from sys import exit
from math import pi

BG_RES = 'resources/backgrounds/'
SQUARE_SIZE = 40
ROWS = 10
COLUMNS = 15

import tower
import enemy
import bullet
import button

class Game():
    def __init__(self) -> None:
        pygame.init() 
        screen = pygame.display.set_mode((1000,600))
        pygame.display.set_caption('Tower Defense')
        clock = pygame.time.Clock()
        
        test_surface = pygame.image.load(BG_RES + 'grid.png')
        
        # tower_group = pygame.sprite.Group()
        tower_group = tower.TowerGroup()
        bullet_group = pygame.sprite.Group()
        enemy_group = pygame.sprite.Group()
        button_group = pygame.sprite.Group()
        
        test_tower = tower.Tower1(10,10)
        test_tower2 = tower.Tower1(1,1)
        tower_group.add(test_tower)
        tower_group.add(test_tower2)
        
        test_enemy = enemy.Enemy1(0,220)
        test_enemy2 = enemy.Enemy1(120,0)
        test_enemy2.angle = 300/180*pi
        enemy_group.add(test_enemy2)
        enemy_group.add(test_enemy)
        
        button_tower1 = button.Button(22,2,'tower1/')
        button_group.add(button_tower1)
        
        
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
                    new_tower = tower.Tower1(x,y)
                    tower_group.add(new_tower) 
                    test_enemy2 = enemy.Enemy1(120,0)
                    test_enemy2.angle = 300/180*pi
                    enemy_group.add(test_enemy2)
                
                if event.type == pygame.KEYDOWN:
                    if event.key == pygame.K_SPACE:
                        test_tower.shoot()
                    if event.key == pygame.K_LEFT:
                        test_tower.rotate(5)
                    if event.key == pygame.K_RIGHT:
                        test_tower.rotate(-5)
                        
                    
            screen.blit(test_surface,(0,0))
            
            enemy_group.update()
            
            tower_group.aim(enemy_group)
            tower_group.shoot(bullet_group)
            
            bullet_group.update()
            tower_group.update()
            
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
        