from typing import Iterable, Union
import pygame
from pygame.sprite import AbstractGroup
from resources import T_RES
from math import sin, cos, pi, sqrt, acos
import bullet

class TowerGroup(pygame.sprite.Group):
    def __init__(self):
        super().__init__()
        
    def aim(self,enemies):
        for tower in self.sprites():
            tower.aim(enemies)

class Tower(pygame.sprite.Sprite):
    def __init__(self, folder):
        super().__init__()
        self.angle = pi/4
        self.images = [pygame.image.load(T_RES+folder+'{}.png'.format(i)).convert_alpha() for i in range(7)]
        self.current_image = 0
        self.image = self.images[self.current_image]
        self.rect = self.image.get_rect(topleft=(40*self.x, 40*self.y))
        self.image.set_colorkey((255, 255, 255))
        self.last_shot_time = 0
        self.is_shooting = False
        self.cadence = 1
        
    def rotate_current(self):
        self.image = pygame.transform.rotate(self.images[int(self.current_image)],self.angle*180/pi-90)
        self.rect = self.image.get_rect(center=(40*self.x + 20, 40*self.y+20))
        self.image.set_colorkey((255, 255, 255))
        
    def dist_to_enemy(self, enemy):
        enemy_pos = enemy.get_position()
        d_x = self.center[0] - enemy_pos[0]
        d_y = self.center[1] - enemy_pos[1]
        return sqrt(d_x**2+d_y**2)
    
    def angle_to_enemy(self, enemy):
        enemy_pos = enemy.get_position()
        d_x =  enemy_pos[0] - self.center[0]
        d_y =  enemy_pos[1] - self.center[1]
        d =  sqrt(d_x**2+d_y**2)
        if d_y < 0:
            return acos(d_x/d)
        return -acos(d_x/d)
        
            
        
    def find_closest_enemy(self, enemy_group):
        enemies = enemy_group.sprites()
        closest_dist = 1000
        if len(enemies) == 0: return None
        
        closest_enemy = enemies[0]
        closest_dist = self.dist_to_enemy(closest_enemy)
        
        if len(enemies) == 1: return closest_enemy
        for enemy in enemies[1:]:
            if self.dist_to_enemy(enemy) < closest_dist:
                closest_enemy = enemy
        return closest_enemy 
            
        
    def aim(self, enemy_group=None):
        closest_enemy = self.find_closest_enemy(enemy_group)
        
        self.angle = self.angle_to_enemy(closest_enemy)
        print("Aiming")
    
    def update(self):
        if self.is_shooting:
            self.current_image += 0.2
            if (self.current_image > (len(self.images)-1)):
                self.current_image = 0
                self.is_shooting = False
        self.rotate_current()
        
    def create_bullet(self):
        return bullet.Bullet(self.center[0], self.center[1], self.angle, speed=3, damage=1)
    
    def shoot(self):
        time = pygame.time.get_ticks()
        if ((time - self.last_shot_time) < 1000/self.cadence): 
            return False
        
        self.last_shot_time = time
        self.is_shooting = True
        return True
        
    def rotate(self,angle):
        self.angle += angle/180*pi
        
    def rotate_to(self,angle):
        self.angle = angle/180*pi
    

        
class Tower1(Tower):
    def __init__(self, x, y):
        self.x = x
        self.y = y
        self.center = [40*x+20,40*y+20]
        super().__init__('tower1/')
        self.cadence = 5
        self.damage = 1
        self.bullet_speed = 3
        
    def create_bullet(self):
        return bullet.Bullet(self.center[0], 
                             self.center[1], 
                             self.angle, 
                             speed=self.bullet_speed, 
                             damage=self.damage,
                             bullet_type='normal')

        