import pygame
import enemy
from math import cos, sin



class Bullet(pygame.sprite.Sprite):
    """A class for a bullet.
    
    ...
    
    Attributes
    ----------
    bullet_type : str
    true_x : float
    true_y : float
    angle : float
    v_x : float
    v_y : float
    damage : int
    speed : int
    image : pygame.image
    rect : pygame.rect
    """
    def __init__(self, pos_x, pos_y, angle, speed, damage, bullet_type, target = None):
        """A constructor.

        ...
        
        Parameters
        ----------
        pos_x : float
            starting x coordinate of the bullet
        pos_y : float
            starting y coordinate of the bullet
        angle : float
            starting angle of the bullet based on the angle of the tower
            in radians
        speed : int
            speed of the bullet defined by the type of the tower
        damage : int
            damage of the bullet defined by the type of the tower
        bullet_type : string
            bullet type defined by the tower
        """
        super().__init__()
        self.bullet_type = bullet_type
        self.damage = damage
        self.true_x = pos_x
        self.true_y = pos_y
        self.angle = angle
        self.speed = speed
        self.target = target
        self.v_x = cos(angle)*speed
        self.v_y = sin(angle)*speed
        self.image = pygame.Surface((5,5))
        self.image.fill((0,0,0))
        self.rect = self.image.get_rect(center=(pos_x+self.v_x, 
                                                pos_y+self.v_y))
    
    def update(self) -> None:
        """Update function - move and chceck whether it is out of the window.
        
        """
        if (self.bullet_type == 'normal') or (self.bullet_type == 'bomb'):
            self.true_x += self.v_x
            self.true_y -= self.v_y
            self.rect.x = int(self.true_x)
            self.rect.y = int(self.true_y)
            
        elif (self.bullet_type == 'missile'):
            if not self.target.alive():
                self.kill()
            bullet_pos = pygame.math.Vector2((self.true_x, self.true_y))
            target_pos = self.target.get_position_vector()
            direction = target_pos - bullet_pos
            direction.scale_to_length(self.speed)
            bullet_pos = bullet_pos + direction
            self.true_x = bullet_pos.x
            self.true_y = bullet_pos.y
            self.rect.x = int(self.true_x)
            self.rect.y = int(self.true_y)
            
            
        if self.is_out():
            self.kill()

        
        
    def is_out(self) -> bool:
        """Check if the bullet left the window.

        ...
        
        Returns
        -------
        bool
            whether the bullet left the window or not
        """
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