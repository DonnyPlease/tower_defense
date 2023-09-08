import pygame
from math import cos, sin



class Bullet(pygame.sprite.Sprite):
    def __init__(self, pos_x, pos_y, angle, speed, damage, bullet_type):
        super().__init__()
        self.bullet_type = bullet_type
        self.damage = damage
        self.true_x = pos_x
        self.true_y = pos_y
        self.v_x = cos(angle)*speed
        self.v_y = sin(angle)*speed
        self.image = pygame.Surface((5,5))
        self.image.fill((0,0,0))
        self.rect = self.image.get_rect(center=(pos_x+self.v_x, pos_y+self.v_y))
    
    def update(self):
        self.true_x += self.v_x
        self.true_y -= self.v_y
        self.rect.x = int(self.true_x)
        self.rect.y = int(self.true_y)
        if self.is_out():
            self.kill()
        
    def is_out(self):
        x = self.rect.x
        y = self.rect.y
        if x < -50:
            return True
        if x > 850:
            return True
        if y < -50:
            return True
        if y > 650:
            return True
        
        return False 