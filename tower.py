from abc import abstractmethod
import pygame
from resources import T_RES
from game import SQUARE_SIZE
from math import sin, cos, pi, sqrt, acos
import bullet
import enemy


class TowerGroup(pygame.sprite.Group):
    """A class for calling certain methods class Tower for all towers at once.
    """
    def __init__(self):
        super().__init__()
        self.banned_squares = []
        self.placed_towers = []
        
    def aim(self, enemies: pygame.sprite.Group):
        """Calls 'aim' method for every Tower in this group. Aiming is choosing
        a target and setting the correct angle so that the bullet can
        hit the target even after it moves.
        
        ...
        
        Parameters
        ----------
        enemies : pygame.sprite.Group:
            A pygame group that manages all live enemies.
            
        Returns
        -------
        None
        """
        for tower in self.sprites():
            tower.aim(enemies)
    
    def shoot(self, bullets: pygame.sprite.Group):
        """This method calls shoot method for every tower in this group and for
        each tower add the new bullet to the bullet group
        
        ...
        
        Parameters
        ----------
        bullets : pygame.sprite.Group
            A group that manages all the bullets in the game.
        
        Returns
        -------
        None
        """
        for tower in self.sprites():
            if tower.shoot():
                bullets.add(tower.create_bullet())
                

class Tower(pygame.sprite.Sprite):
    """A class that manages a tower behaviour. It inherits most of its
    methods from class pygame.sprite.Sprite.
    
    ...
    
    Attributes
    ----------
    angle : float
        angle of direction in radians - 0 represents 3 o'clock and 
        positive rotation is counter-clockwise
    
    """
    def __init__(self, folder : str):
        """Constructor. It needs the path to folder where the images of
        a particular tower is stored. It should be called only from a child
        class where other things are specified. There should not exist
        an instance of this class.

        Parameters
        ----------
        folder : str 
            A path to a folder where the images for the tower are stored. There
            should be all images of the shoot animation including all three
            button states.
        """
        super().__init__()
        self.angle = pi/2   # Angle of where the tower points in radians. 
                            # 0 rad is 3  o'clock.
                            
        # Load all images for the animation.
        self.images = [pygame.image.load(
            T_RES+folder+'{}.png'.format(i)).convert_alpha() for i in range(7)]
        self.current_image = 0  # Index of current image.
        self.image = self.images[self.current_image]    # Choose current image.
        # Get rectangle.
        self.rect = self.image.get_rect(topleft=(SQUARE_SIZE*self.x, 
                                                 SQUARE_SIZE*self.y))
        self.image.set_colorkey((255, 255, 255))    # This is for transparency.
        self.last_shot_time = 0 # Define variable for the time of the last shot
        
        # Two variables specifying the state of the tower
        self.is_shooting = False
        self.aimed = False 
        self.closest_enemy = None

    def rotate_current(self) -> None:
        """Rotates current image to the current angle stored in attribute 
        self.angle.
        
        ...
        
        Returns
        -------
        None
        """
        angle_deg = self.angle*180/pi-90  # Convert angle from radians 
                                          # to degress andoffset by 90 degrees
                                          
        # Use pygame.transform.rotate to rotate current image with angle in 
        # degrees.
        self.image = pygame.transform.rotate(
            self.images[int(self.current_image)],angle=angle_deg)
        
        # Rotated image has to be re-positioned.
        self.rect = self.image.get_rect(
            center=(SQUARE_SIZE*self.x + SQUARE_SIZE//2, 
                    SQUARE_SIZE*self.y+SQUARE_SIZE//2))
        self.image.set_colorkey((255, 255, 255))
        
    def dist_to_enemy(self, enemy: enemy.Enemy) -> float:
        """Calculates the distance between this tower and enemy passed as an 
        argument.
        
        ...
        
        Parameters
        ----------
        enemy : enemy.Enemy
        
        Returns
        -------
        float
            The distance from self to enemy.
        """
        enemy_pos = enemy.get_position()
        d_x = self.center[0] - enemy_pos[0]
        d_y = self.center[1] - enemy_pos[1]
        return sqrt(d_x*d_x + d_y*d_y)
    
    def angle_to_enemy(self, enemy : enemy.Enemy):
        enemy_pos = enemy.get_position_vector()
        d_x =  enemy_pos.x - self.center[0]
        d_y =  enemy_pos.y - self.center[1]
        d =  sqrt(d_x*d_x + d_y*d_y)
        if d_y < 0:
            return acos(d_x/d)
        return -acos(d_x/d)
    
    def angle_to_enemy_prediction(self, enemy : enemy.Enemy) -> float:
        """Calculates the correct aiming angle to the enemy considering its
        movement. The quadratic equation is solved each time to predict the
        position of the enemy in time the bullet arrives. This function is 
        therefore a little slow and does not have to be used in the case of
        very fast bullets, lasers or bombs.
        ...
        
        Parameters
        ----------
        enemy : enemy.Enemy
            
        Returns
        -------
        float
            The aiming angle in to the enemy in radians with the consideration 
            of its movement.
        """
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
        
    def find_closest_enemy(self, 
                           enemy_group : pygame.sprite.Group) -> enemy.Enemy:
        """This function finds the closest enemy to this tower (self) and
        returns the whole sprite.
        
        ...

        Parameters
        ----------
        enemy_group : pygame.sprite.Group
            Group of enemies of the whole game.

        Returns
        -------
        enemy.Enemy
            An instance of enemy that is the closest to this tower.            
        """
        enemies = enemy_group.sprites()  # Get list of sprites
        closest_dist = 10000  # Initialize ridiculously large distance
        if len(enemies) == 0: return None # If the list is empty return none.
        
        closest_enemy = enemies[0]  # Take first enemy
        closest_dist = self.dist_to_enemy(closest_enemy)
        
        if len(enemies) == 1: return closest_enemy
        for enemy in enemies[1:]:
            new_dist = self.dist_to_enemy(enemy)
            if new_dist < closest_dist:
                closest_enemy = enemy
                closest_dist = new_dist 
        return closest_enemy 
               
    def aim(self, enemy_group: pygame.sprite.Group) -> None:
        """This function changes the angle of this tower so that it cane shoot
        a bullet in the right direction. It also changes the ''self.aimed'' 
        state depending on whether there is some enemy in alive in the range
        of this tower.
        
        ...
        
        Parameters
        ----------
        enemy_group : pygame.sprite.Group
            Group of all enemies in the game.
            
        Returns
        -------
        None
        """
        # Set self.aimed to False if there is no living enemy in the game.
        if len(enemy_group) == 0: 
            self.aimed = False
            return
        
        # Find closest enemy and if it is in the range, aim the tower to it and
        # (set 'self.aimed' to True). Else set 'self.aimed' to False.
        self.closest_enemy = self.find_closest_enemy(enemy_group)
        if self.dist_to_enemy(self.closest_enemy)>self.range:
            self.aimed = False
            return
        self.aimed = True
        if self.bullet_type == 'missile':
            self.angle = self.angle_to_enemy(self.closest_enemy)
            return
        self.angle = self.angle_to_enemy_prediction(self.closest_enemy)
        
    
    def update(self) -> None:
        """Update function can be called from group by default. 
        It includes some classic behaviour. It updates the animation -
        it increments the 'self.current_image' by fractions so that the
        'self.draw' function can draw the right image. It also rotates 
        the image of the tower to the current angle.
        
        ...
        
        Returns
        ------
        None
        """
        if self.is_shooting:
            self.current_image += 0.2
            if (self.current_image > (len(self.images)-1)):
                self.current_image = 0
                self.is_shooting = False
        self.rotate_current()
        
    
    def shoot(self) -> bool:
        """Shoot a bullet if the conditions are met. The conditions include
        checking the time passed since the last shooted bullet.
        
        ...
        
        Returns
        -------
        bool
            whether the bullet is shot or not yet
        """
        time = pygame.time.get_ticks()
        if ((time-self.last_shot_time) < 1000/self.cadence) or not self.aimed: 
            return False
        
        self.last_shot_time = time
        self.is_shooting = True
        return True
        
    @abstractmethod
    def create_bullet(self):
        """Abstract method. It should be implemented in the child.
        
        ...
        
        Returns 
        -------
        bullet.Bullet
            A bullet with parameters that are specific for the particular
            type of tower.
        """
        pass

        
class Tower1(Tower):
    def __init__(self, x, y):
        self.x = x
        self.y = y
        self.center = [SQUARE_SIZE*x+SQUARE_SIZE//2,
                       SQUARE_SIZE*y+SQUARE_SIZE//2]
        super().__init__('tower1/')
        self.cadence = 1
        self.damage = 2
        self.bullet_speed = 2
        self.bullet_type = 'missile'
        self.range = 300
        self.cost = 50
        
    def create_bullet(self):
        """Bullet for Tower1.
        
        ...
        
        Returns
        -------
        bullet.Bullet
            A fired bullet.
        """
        return bullet.Bullet(self.center[0], 
                             self.center[1], 
                             self.angle, 
                             speed=self.bullet_speed, 
                             damage=self.damage,
                             bullet_type=self.bullet_type,
                             target=self.closest_enemy)

        
        
class Tower2(Tower):
    def __init__(self, x, y):
        self.x = x
        self.y = y
        self.center = [SQUARE_SIZE*x+SQUARE_SIZE//2,
                       SQUARE_SIZE*y+SQUARE_SIZE//2]
        super().__init__('tower2/')
        self.cadence = 2
        self.damage = 1
        self.bullet_speed = 35
        self.range = 200
        self.cost = 100
        self.bullet_type='normal'
        
    def create_bullet(self):
        """Bullet for class Tower2.
        
        ...
        
        Returns
        -------
        bullet.Bullet
            A fired bullet.
        """
        return bullet.Bullet(self.center[0], 
                             self.center[1], 
                             self.angle, 
                             speed=self.bullet_speed, 
                             damage=self.damage,
                             bullet_type='normal')

        