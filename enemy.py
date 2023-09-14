import pygame
from math import sin, cos, pi
from resources import E_RES
from random import random,randint
from game import SQUARE_SIZE
import map_path


class Enemy(pygame.sprite.Sprite):
    def __init__(self, game):
        super().__init__()
        self.start = game.map_start[randint(0,len(game.map_start)-1)]
        self.end = game.map_end[randint(0,len(game.map_end)-1)]
        self.global_path = game.map_path
        self.path = map_path.find_shortest_path(self.global_path, self.start, self.end)
        self.true_x = self.start[0]*40 + 20
        self.true_y = self.start[1]*40 + 20
        self.angle = 0
        self.v_x = 0
        self.v_y = 0
        self.reward = 0
        self.update_velocity()
    
    def update_path(self,new_global_path):
        self.global_path = new_global_path
        start = (int(self.true_x), int(self.true_y))
        self.path = map_path.find_shortest_path(self.global_path,start,self.end)
    
    def update_velocity(self):
        # d_a = 0.1*random()-0.05
        # self.angle += d_a
        self.v_x = cos(self.angle*180/pi)*self.speed
        self.v_y = sin(self.angle*180/pi)*self.speed
       
    def get_position(self):
        return [self.true_x, self.true_y]
    
    def get_position_vector(self):
        return pygame.math.Vector2((self.true_x, self.true_y))
       
    def get_velocity(self):
        return [self.v_x, self.v_y]
    
    def hit(self, damage):
        self.hitpoints -= damage
        if self.hitpoints <= 0:
            self.kill()
            return self.reward
     
    def update_position(self):
        if len(self.path)>1:                
            pos = self.get_position_vector()
            direction = pygame.math.Vector2(self.path[0])*40 + pygame.math.Vector2((20,20)) - pos
            if direction.length() <= self.speed:
                self.path.pop(0)
                direction = pygame.math.Vector2(self.path[0])*40 + pygame.math.Vector2((20,20)) - pos
                
            direction.scale_to_length(self.speed)
            pos = pos + direction    
            self.angle = direction.angle_to(pygame.math.Vector2((1,0)))/180*pi    
            self.true_x = pos.x
            self.true_y = pos.y
        else:
            self.true_x += self.v_x
            self.true_y += self.v_y
            
    def update(self):
        self.update_velocity()
        self.update_position()        
        self.rotate()
        self.rect = self.image.get_rect(center=(int(self.true_x),int(self.true_y)))
    
    def rotate(self):
        self.image = pygame.transform.rotate(self.image_orig,self.angle*180/pi)
        self.rect = self.image.get_rect(center=(SQUARE_SIZE*int(self.true_x) + 20, SQUARE_SIZE*int(self.true_y)+20))
        self.image.set_colorkey((255, 255, 255))
        

        

class Enemy1(Enemy):
    def __init__(self, game):
        self.speed = 1
        self.hitpoints = 20
        super().__init__(game)
        self.image_orig = pygame.image.load(E_RES+'enemy1/0.png').convert_alpha()
        self.image = self.image_orig
        self.image.set_colorkey((255, 255, 255))
        self.reward = 10
        
        
        