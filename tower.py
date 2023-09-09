from typing import Iterable, Union
import pygame
from pygame.sprite import AbstractGroup
from resources import T_RES
from game import SQUARE_SIZE
from math import sin, cos, pi, sqrt, acos
import bullet


class TowerGroup(pygame.sprite.Group):
    def __init__(self):
        super().__init__()
        
    def aim(self, enemies):
        for tower in self.sprites():
            tower.aim(enemies)
    
    def shoot(self, bullets):
        for tower in self.sprites():
            if tower.shoot():
                bullets.add(tower.create_bullet())
                

class Tower(pygame.sprite.Sprite):
    def __init__(self, folder):
        super().__init__()
        self.angle = pi/4
        self.images = [pygame.image.load(T_RES+folder+'{}.png'.format(i)).convert_alpha() for i in range(7)]
        self.current_image = 0
        self.image = self.images[self.current_image]
        self.rect = self.image.get_rect(topleft=(SQUARE_SIZE*self.x, SQUARE_SIZE*self.y))
        self.image.set_colorkey((255, 255, 255))
        self.last_shot_time = 0
        self.is_shooting = False
        self.cadence = 1
        self.aimed = False
        
    def rotate_current(self):
        self.image = pygame.transform.rotate(self.images[int(self.current_image)],self.angle*180/pi-90)
        self.rect = self.image.get_rect(center=(SQUARE_SIZE*self.x + 20, SQUARE_SIZE*self.y+20))
        self.image.set_colorkey((255, 255, 255))
        
    def dist_to_enemy(self, enemy):
        enemy_pos = enemy.get_position()
        d_x = self.center[0] - enemy_pos[0]
        d_y = self.center[1] - enemy_pos[1]
        return sqrt(d_x*d_x + d_y*d_y)
    
    def angle_to_enemy(self, enemy):
        enemy_pos = enemy.get_position()
        d_x =  enemy_pos[0] - self.center[0]
        d_y =  enemy_pos[1] - self.center[1]
        a = enemy.speed**2 - self.bullet_speed**2
        b = 2 * (enemy.v_x*d_x - enemy.v_y*d_y)
        c = d_x*d_x + d_y*d_y
        p = -b / 2 / a
        q = sqrt(b*b -4 * a * c) / 2 / a
        t1 = p - q
        t2 = p + q
        t = 0
        if (t1>t2) and (t2>0):
            t = t2
        else:
            t = t1
        future_position_x = enemy_pos[0] + enemy.v_x*t
        future_position_y = enemy_pos[1] - enemy.v_y*t
        d_x =  future_position_x - self.center[0]
        d_y =  future_position_y - self.center[1]
        d =  sqrt(d_x*d_x + d_y*d_y)
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
            new_dist = self.dist_to_enemy(enemy)
            if new_dist < closest_dist:
                closest_enemy = enemy
                closest_dist = new_dist 
        return closest_enemy 
               
    def aim(self, enemy_group):
        if len(enemy_group) == 0: 
            self.aimed = False
            return
        closest_enemy = self.find_closest_enemy(enemy_group)
        if self.dist_to_enemy(closest_enemy)>self.range:
            self.aimed = False
            return
        self.aimed = True
        self.angle = self.angle_to_enemy(closest_enemy)
        
    
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
        if ((time - self.last_shot_time) < 1000/self.cadence) or not self.aimed: 
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
        self.center = [SQUARE_SIZE*x+SQUARE_SIZE//2,SQUARE_SIZE*y+SQUARE_SIZE//2]
        super().__init__('tower1/')
        self.cadence = 1
        self.damage = 2
        self.bullet_speed = 4
        self.range = 300
        self.cost = 0
        
    def create_bullet(self):
        return bullet.Bullet(self.center[0], 
                             self.center[1], 
                             self.angle, 
                             speed=self.bullet_speed, 
                             damage=self.damage,
                             bullet_type='normal')

        