import pygame
from math import sin, cos, pi
from resources import E_RES
from random import random, randint
from game import SQUARE_SIZE
import map_path


class EnemyGroup(pygame.sprite.Group):
    def __init__(self):
        super().__init__()
    def draw(self, screen):
        super().draw(screen)
        for en in self.sprites():
            max_hp = en.max_hitpoints
            hp = en.hitpoints
            x, y = en.get_pos()
            rect = pygame.Rect(x - 10, y - 25, 20, 5)
            pygame.draw.rect(screen, (255, 0, 0), rect)
            hp_rect = pygame.Rect(x - 10, y - 25, int(20 * hp / max_hp), 5)
            pygame.draw.rect(screen, (0, 255, 0), hp_rect)


class Enemy(pygame.sprite.Sprite):
    """A class of enemy. It is used as a parent class for the particular
    types of enemies. All attributes are specified in the documentation of
    the child classes.
    """

    def __init__(self, game):
        super().__init__()
        self.start = game.map_start[randint(0, len(game.map_start)-1)]
        self.end = game.map_end[randint(0, len(game.map_end)-1)]
        self.global_path = game.map_path
        self.path = map_path.find_shortest_path(
            self.global_path, self.start, self.end)
        self.true_x = self.start[0]*40 + 20
        self.true_y = self.start[1]*40 + 20
        self.angle = 0
        self.v_x = 0
        self.v_y = 0
        self.reward = 0
        self.update_velocity()

    def get_pos(self):
        return (int(self.true_x), int(self.true_y))

    def update_path(self, new_global_path) -> None:
        """Updated the path. In case of a square being removed from the 
        'self.global_path'.

        ...

        Parameters
        ----------
        new_global_path : list 
            list of points [row,col], where row represents the index of row
            and col represents the index of column of that point

        Returns
        -------
        None
        """
        # TODO: Test this function
        self.global_path = new_global_path
        start = (int(self.true_x), int(self.true_y))
        self.path = map_path.find_shortest_path(
            self.global_path, start, self.end)

    def update_velocity(self) -> None:
        """Update the vector of velocity based on 'self.angle'.

        ...

        Returns
        None"""
        # d_a = 0.1*random()-0.05
        # self.angle += d_a

        angle = self.angle*180/pi  # Convert from radians to degrees.
        self.v_x = cos(angle)*self.speed
        self.v_y = sin(angle)*self.speed

    def get_position(self):
        """A getter of [self.true_x, self.true_y].

        ...

        Returns
        list
            [self.true_x, self.true_y]
        """
        return [self.true_x, self.true_y]

    def get_position_vector(self) -> pygame.math.Vector2:
        """Getter of pygame vector of position.

        ...

        Returns
        -------
        pygame.math.Vector2
            vector of position
        """
        return pygame.math.Vector2((self.true_x, self.true_y))

    def get_velocity(self):
        """A getter of [self.v_x, self.v_y].

        ...

        Returns
        list
            [self.v_x, self.v_y]
        """
        return [self.v_x, self.v_y]

    def hit(self, damage: int):
        """Call when bullet collides with a bullet. Decrements the enemy
        lifepoints by damage of the bullet. Calls 'self.kill()' when the
        enemy is dead. Returns None if the enemy survived the bullet.
        Return 'self.reward' if it dies.

        ...

        Parameters
        ----------
        damage : int
            bullet.damage of the particular bullet that collided with
            the enemy

        Returns:
        None or int
            reward for killing the enemy 
        """
        self.hitpoints -= damage
        if self.hitpoints <= 0:
            self.kill()
            return self.reward
        return 0

    def update_position(self) -> None:
        """Updating the position based on the path the enemy is supposed
        to follow.

        ...

        Returns
        -------
        None
        """
        if len(self.path) > 1:
            pos = self.get_position_vector()
            direction = pygame.math.Vector2(
                self.path[0])*40 + pygame.math.Vector2((20, 20)) - pos
            if direction.length() <= self.speed:
                self.path.pop(0)
                direction = pygame.math.Vector2(
                    self.path[0])*40 + pygame.math.Vector2((20, 20)) - pos

            direction.scale_to_length(self.speed)
            pos = pos + direction
            self.angle = direction.angle_to(pygame.math.Vector2((1, 0)))/180*pi
            self.v_x = pos.x - self.true_x
            self.v_y = pos.y - self.true_y
            self.true_x = pos.x
            self.true_y = pos.y
        else:
            self.true_x += self.v_x
            self.true_y += self.v_y

            if self.true_x > 819 or self.true_y > 619:
                self.kill()

    def update(self) -> None:
        """The implementation of the update function so it can be called from 
        the group of enemies on all of them at once. It is a code that is run
        before drawing each frame.

        ...

        Returns
        -------
        None
        """
        # self.update_velocity()
        self.update_position()

        self.rotate()
        self.rect = self.image.get_rect(center=(int(self.true_x),
                                                int(self.true_y)))

    def rotate(self):
        """Rotate image based on current angle.

        ...

        Returns
        -------
        None
        """
        self.image = pygame.transform.rotate(self.image_orig,
                                             self.angle*180/pi)
        self.rect = self.image.get_rect(center=(SQUARE_SIZE*int(self.true_x) + 20,
                                                SQUARE_SIZE*int(self.true_y)+20))
        self.image.set_colorkey((255, 255, 255))


class Enemy1(Enemy):
    """Class derived from Enemy. It represents a particular setting
    of the enemy as well as it specifies the images used to depict the enemy
    during the game.

    ...

    Attributes
    ----------
    speed : int 
        speed of the enemy in pixels per screen update
    hitpoints : int
        damage the enemy can withstand before dying
    start : 
    end :
    path : list
    global_path : list
    image :
    rect :
    reward : int
        reward for killing the enemy
    true_x : float
        actual x position of the enemy
    true_y : float
        actual y position of the enemy
    v_x : float
        velocity in the x direction
    v_y : float
        velocity in the y direction
    angle : float
        angle of the enemy with relationship to 3 o'clock
    """

    def __init__(self, game):
        """A constructor.

        ...

        Parameters
        ----------
        game : game.Game
            an instance of the current game so the enemy can access the all
            the available squares, start and end
        """
        self.speed = 1.5
        self.hitpoints = 20
        self.max_hitpoints = 20
        super().__init__(game)
        self.image_orig = pygame.image.load(
            E_RES+'enemy1/0.png').convert_alpha()
        self.image = self.image_orig
        self.image.set_colorkey((255, 255, 255))
        self.reward = 50
        self.rect = self.image.get_rect(center=(int(self.true_x),
                                                int(self.true_y)))
        

class Enemy2(Enemy):
    """Class derived from Enemy. It represents a particular setting
    of the enemy as well as it specifies the images used to depict the enemy
    during the game.

    ...

    Attributes
    ----------
    speed : int 
        speed of the enemy in pixels per screen update
    hitpoints : int
        damage the enemy can withstand before dying
    start : 
    end :
    path : list
    global_path : list
    image :
    rect :
    reward : int
        reward for killing the enemy
    true_x : float
        actual x position of the enemy
    true_y : float
        actual y position of the enemy
    v_x : float
        velocity in the x direction
    v_y : float
        velocity in the y direction
    angle : float
        angle of the enemy with relationship to 3 o'clock
    """

    def __init__(self, game):
        """A constructor.

        ...

        Parameters
        ----------
        game : game.Game
            an instance of the current game so the enemy can access the all
            the available squares, start and end
        """
        self.speed = 3.5
        self.hitpoints = 80
        self.max_hitpoints = 80
        super().__init__(game)
        self.image_orig = pygame.image.load(
            E_RES+'enemy2/0.png').convert_alpha()
        self.image = self.image_orig
        self.image.set_colorkey((255, 255, 255))
        self.reward = 300
        self.rect = self.image.get_rect(center=(int(self.true_x),
                                                int(self.true_y)))
        

class Enemy3(Enemy):
    """Class derived from Enemy. It represents a particular setting
    of the enemy as well as it specifies the images used to depict the enemy
    during the game.

    ...

    Attributes
    ----------
    speed : int 
        speed of the enemy in pixels per screen update
    hitpoints : int
        damage the enemy can withstand before dying
    start : 
    end :
    path : list
    global_path : list
    image :
    rect :
    reward : int
        reward for killing the enemy
    true_x : float
        actual x position of the enemy
    true_y : float
        actual y position of the enemy
    v_x : float
        velocity in the x direction
    v_y : float
        velocity in the y direction
    angle : float
        angle of the enemy with relationship to 3 o'clock
    """

    def __init__(self, game):
        """A constructor.

        ...

        Parameters
        ----------
        game : game.Game
            an instance of the current game so the enemy can access the all
            the available squares, start and end
        """
        self.speed = 5.5
        self.hitpoints = 20
        self.max_hitpoints = 20
        super().__init__(game)
        self.image_orig = pygame.image.load(
            E_RES+'enemy3/0.png').convert_alpha()
        self.image = self.image_orig
        self.image.set_colorkey((255, 255, 255))
        self.reward = 100
        self.rect = self.image.get_rect(center=(int(self.true_x),
                                                int(self.true_y)))
        
enemies_dict = {pygame.K_1: Enemy1,
                pygame.K_2: Enemy2,
                pygame.K_3: Enemy3}