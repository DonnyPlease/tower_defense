import pygame
from math import sin, cos, pi


class Enemy(pygame.sprite.Sprite):
    def __init__(self):
        super().__init__()
        self.true_x = 0
        self.true_y = 200
        self.angle = 0
        self.v_x = 0
        self.v_y = 0
        self.update_velocity()
        
    def update_velocity(self):
        angle = self.angle   
        self.v_x = cos(angle)*self.speed
        self.v_y = sin(angle)*self.speed
       
    def get_velocity(self):
        return [self.v_x, self.v_y]
    
    def hit(self, damage):
        self.hitpoints -= damage
        if self.hitpoints <= 0:
            self.kill()
     
    def update_position(self):
        self.true_x += self.v_x
        self.true_y -= self.v_y
        self.rect.x = int(self.true_x)
        self.rect.y = int(self.true_y)

    def update(self):
        self.update_velocity()
        self.update_position()        
        

class Enemy1(Enemy):
    def __init__(self):
        self.speed = 1
        self.hitpoints = 5
        super().__init__()
        self.image = pygame.Surface((30,30))
        self.image.fill((255,0,0))
        self.rect = self.image.get_rect(center=(int(self.true_x),int(self.true_y)))
        
        
        