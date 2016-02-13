//
//  plpMyScene.m: the scene subclass
//
//  Edgar The Explorer
//
//  Copyright (c) 2014-2016 Filipe Mathez and Paul Ronga
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU Lesser General Public License as published by
//  the Free Software Foundation; either version 2.1 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
//  GNU Lesser General Public License for more details.
//
//  You should have received a copy of the GNU Lesser General Public License
//  along with this program; if not, write to the Free Software Foundation,
//  Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
//
////////////////////////////////////////////////////////////////////////////////////////////

#import "plpMyScene.h"

@implementation plpMyScene

NSArray *_monstreWalkingFrames;
SKSpriteNode *_monstre;

typedef NS_OPTIONS(uint32_t, MyPhysicsCategory) // pour eviter le contact entre certains objets
{
    PhysicsCategoryEdgar = 1 << 0,   // 1
    PhysicsCategoryObjects = 1 << 1, // 2
    PhysicsCategoryTiles = 1 << 2,   // 4
    PhysicsCategoryAliens = 1 << 3,  // 8
    PhysicsCategorySensors = 1 << 4, // 16
    PhysicsCategoryItems = 1 << 5    // 32
};


-(id)initWithSize:(CGSize)size {
    if (self = [super initWithSize:size]) {
        self.physicsWorld.contactDelegate = self;
        self.size = CGSizeMake(800, 400);// => moitie de la largeur = 400 // En fait, coordonnees: 754 x 394
        
        myWorld = [SKNode node];         // Creation du "monde" sur lequel tout est fixe
        myWorld.name = @"world";
        [self addChild:myWorld];
        
        myCamera = [SKCameraNode node];
        self.camera = myCamera;
        [self addChild:myCamera];
        
        
        // Actions
        SKAction *mvm1 = [SKAction runBlock:^{
            [Edgar.physicsBody setVelocity:CGVectorMake(EdgarVelocity + contextVelocityX, Edgar.physicsBody.velocity.dy)];        }];
        SKAction *mvm2 = [SKAction runBlock:^{
            [Edgar.physicsBody setVelocity:CGVectorMake(-EdgarVelocity + contextVelocityX, Edgar.physicsBody.velocity.dy)];
        }];
        SKAction *wait = [SKAction waitForDuration:.05]; // = 20 fois par seconde vs 60

        EdgarVelocity = 140;
        
        bougeDroite = [SKAction sequence:@[mvm1, wait]];
        bougeGauche = [SKAction sequence:@[mvm2, wait]];
        
        bougeGauche2 = [SKAction repeatActionForever:bougeGauche];
        bougeDroite2 = [SKAction repeatActionForever:bougeDroite];
        
        // Premier chargement de la carte des tiles
        myLevel = [self loadLevel:0];
        [myWorld addChild: myLevel];
        [self addStoneBlocks:myLevel];

        [self loadAssets:myLevel];

        Edgar = [[plpHero alloc] initAtPosition: CGPointMake(startPosition.x, startPosition.y)];
        myCamera.position = startPosition;
        
        Edgar.physicsBody.categoryBitMask = PhysicsCategoryEdgar;
        Edgar.physicsBody.collisionBitMask = PhysicsCategoryObjects|PhysicsCategoryTiles;
        Edgar.physicsBody.contactTestBitMask = PhysicsCategoryObjects|PhysicsCategoryTiles|PhysicsCategoryAliens|PhysicsCategorySensors|PhysicsCategoryItems;
        
        Edgar->rectangleNode.physicsBody.categoryBitMask = PhysicsCategoryEdgar;
        Edgar->rectangleNode.physicsBody.collisionBitMask = PhysicsCategoryObjects|PhysicsCategoryTiles;
        Edgar->rectangleNode.physicsBody.contactTestBitMask = PhysicsCategoryObjects|PhysicsCategoryTiles|PhysicsCategoryAliens|PhysicsCategorySensors|PhysicsCategoryItems;
        
        listensToContactEvents = TRUE;
        
        [myLevel addChild: Edgar];
        SKPhysicsJointFixed *pinEdgar = [SKPhysicsJointFixed jointWithBodyA:Edgar.physicsBody bodyB:Edgar->rectangleNode.physicsBody anchor:CGPointMake(Edgar.position.x, Edgar.position.y)];
        [self.physicsWorld addJoint:pinEdgar];
        
        NSURL *url = [[NSBundle mainBundle] URLForResource:@"Sounds/Juno" withExtension:@"mp3"];
        NSError *error = nil;
        
        self.audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&error];
        self.audioPlayer.numberOfLoops = -1;
        if (!self.audioPlayer) {
            NSLog(@"Error creating player: %@", error);
        }
        [self.audioPlayer play];
    }
    return self;
}


- (IBAction)inGameButtonClicked:(id)sender {
    NSLog(@"clic.");
    if(nextLevelIndex == LAST_LEVEL_INDEX)
    {
//        [super pauseButtonClicked:sender];
        nextLevelIndex = 0;
    }
}

- (JSTileMap*)loadLevel:(int)levelIndex
{
    JSTileMap *myTileMap;
    NSArray *levelFiles = [NSArray arrayWithObjects:
                           @"Level_1_tuto.tmx",
                           @"Level_2.tmx",
                           @"Level_3.tmx",
                           @"Level_4.tmx",
                           @"Level_5.tmx",
                           @"Level_6.tmx", // !! erreur si fichier ne se charge pas! Ajouter un test
                           @"Level_7.tmx",
                           nil];
/*    NSArray *levelNames = [NSArray arrayWithObjects:  -> removed: level names
                           @"Entrance",
                           @"Cloakroom",
                           @"Control room",
                           @"Laboratory",
                           @"The Cell",
                           nil];*/
    
    NSString *myLevelFile;
    
    if(levelIndex < [levelFiles count])
    {
         myLevelFile = levelFiles[levelIndex];
    }
    
    if(myLevelFile)
    {
        // !!!!! Ajouter un try / catch ou similaire
        myTileMap = [JSTileMap mapNamed:myLevelFile];
        if(!myTileMap)
        {
            NSLog(@"Erreur de chargement de la carte.");
        }
    }
    
/*    if(levelIndex > -1)   To display level names
    {
        if(levelIndex < [levelNames count])
        {
            SKLabelNode *levelName= [SKLabelNode labelNodeWithFontNamed:@"Chalkduster"];
            levelName.text = [NSString stringWithFormat:@"Level %d: %@", levelIndex + 1, levelNames[levelIndex]];//@"";
            levelName.fontSize = 50;
            levelName.fontColor = [SKColor redColor];
            levelName.position = CGPointMake(400, 200);
            [self addChild:levelName];
            
            SKAction *titleVanish = [SKAction sequence: @[[SKAction waitForDuration:1.5],[SKAction fadeAlphaTo:0 duration:.5], [SKAction removeFromParent]]];
            [levelName runAction:titleVanish];
        }
    }*/
    
    return myTileMap;
}

-(void)addStoneBlocks: (JSTileMap*) tileMap
{
    TMXLayer* monLayer = [tileMap layerNamed:@"Solide"];
    
    for (int a = 0; a < tileMap.mapSize.width; a++)
    {
        for (int b = 0; b < tileMap.mapSize.height; b++)
        {
            CGPoint pt = CGPointMake(a, b);
            
            NSInteger gid = [monLayer tileGidAt:[monLayer pointForCoord:pt]];
            
            if (gid != 0)
            {
                SKSpriteNode* node = [monLayer tileAtCoord:pt];
                [node setScale: 1.01f]; // ddd tentative
                node.physicsBody = [SKPhysicsBody bodyWithTexture:node.texture size:node.frame.size];
                node.physicsBody.dynamic = NO;
                node.physicsBody.categoryBitMask = PhysicsCategoryTiles;
                node.physicsBody.friction = 0.5;
                node.physicsBody.restitution = 0;
                if(node.physicsBody){
                    node.shadowCastBitMask = 1;
                }else{
                    NSLog(@"%d, %d: Le physicsBody n'a pas été créé, pas d'ombre", a, b);
                }
            }
        }
    }
}

-(CGPoint) convertPosition:(NSDictionary*)objectDictionary
{
    CGPoint thePoint = CGPointMake([objectDictionary[@"x"] floatValue] + ([objectDictionary[@"width"] floatValue]/2),
                       [objectDictionary[@"y"] floatValue] + ([objectDictionary[@"height"] floatValue]/2));
    return thePoint;
}

-(void)loadAssets:(JSTileMap*) tileMap
{
    // Position de depart d'Edgar
    TMXObjectGroup *group = [tileMap groupNamed:@"Objets"]; // Objets
    if(!group) NSLog(@"Erreur: pas de calque Objets dans la carte.");
    NSArray *startPosObjects = [group objectsNamed:@"Start"];
    for (NSDictionary *startPos in startPosObjects) {
        startPosition = [self convertPosition:startPos];
    }
    
    if(nextLevelIndex==1) // Fin du niveau 1: on efface l'éventuel reste de flèche d'aide
    {
        SKNode *theNode;
        if(( theNode = [myCamera childNodeWithName:@"helpNode"]))
        {
            [theNode removeFromParent];
        }
    }
    
    if(nextLevelIndex>1)
    {
        SKSpriteNode *startLift = [SKSpriteNode spriteNodeWithTexture:[SKTexture textureWithImageNamed:@"ascenseur-start.png"] size: CGSizeMake(88, 106)];
        startLift.position = startPosition;
        [tileMap addChild: startLift];
    }
 
    // Senseur (utilisés pour déclencher la fin du  niveau et des événements comme la venue du vaisseau spatial)
    // Sensor (detects when the player reaches the center of the lift and triggers events like the alien vessel)
    NSArray *sensorObjectMarker;
    if((sensorObjectMarker = [group objectsNamed:@"sensor"]))
    {
        SKSpriteNode *sensorNode;
        int sensorId;
        
        for (NSDictionary *theSensor in sensorObjectMarker) {
            NSLog(@"Création d'un senseur");
            float width = [theSensor[@"width"] floatValue];
            float height = [theSensor [@"height"] floatValue];
            sensorNode = [SKSpriteNode spriteNodeWithColor:[UIColor colorWithRed:1 green: 1                                                                                blue: 1 alpha: 0] size: CGSizeMake(width, height)];
            sensorNode.position = [self convertPosition:theSensor];
            
            if(sensorNode)
            {
                sensorNode.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:CGSizeMake(width, height)];
                sensorNode.physicsBody.dynamic = NO;
                sensorNode.physicsBody.categoryBitMask = PhysicsCategorySensors;
                sensorNode.physicsBody.collisionBitMask = 0;
                if(theSensor[@"nodename"])
                {
                    sensorNode.name = theSensor[@"nodename"];
                    NSLog(@"Senseur avec nom _%@_ créé", theSensor[@"nodename"]);
                }
                else
                {
                    sensorNode.name = [NSString stringWithFormat:@"sensor%d", sensorId];
                    NSLog(@"Senseur avec id %d créé", sensorId);
                }
                sensorId++;
                [tileMap addChild:sensorNode];
                NSLog(@"Senseur ajouté.");
            }
            else
            {
                NSLog(@"Erreur lors de la création d'un senseur");
            }
        }
    }
    
    // Crate / Caisse
    SKTexture *textureCaisse = [SKTexture textureWithImageNamed:@"box-08.png"];
    NSArray *placeCaisse = [group objectsNamed:@"Caisse"];
    for (NSDictionary *optionCaisse in placeCaisse) {
        CGFloat width = [optionCaisse[@"width"] floatValue];
        CGFloat height = [optionCaisse[@"height"] floatValue];
        
        SKSpriteNode *caisse = [SKSpriteNode spriteNodeWithTexture:textureCaisse size: CGSizeMake(width, height)];
        caisse.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:CGSizeMake(width, height)];
        caisse.physicsBody.mass = 20; // auparavant: 40
        caisse.physicsBody.friction = 0.1;
        caisse.position = [self convertPosition:optionCaisse];
        caisse.physicsBody.categoryBitMask = PhysicsCategoryObjects;
//        caisse.zPosition = -4; // devant les autres objets
        caisse.physicsBody.collisionBitMask = PhysicsCategoryEdgar|PhysicsCategoryObjects|PhysicsCategoryTiles;
        [tileMap addChild: caisse];
        
        if(nextLevelIndex == 4)
        {
            [caisse runAction:[SKAction repeatActionForever:[SKAction sequence:@[[SKAction colorizeWithColor:[SKColor redColor] colorBlendFactor:1.0 duration:.2],[SKAction waitForDuration:2.8],[SKAction colorizeWithColor:[SKColor greenColor] colorBlendFactor:1.0 duration:.2], [SKAction waitForDuration:2.8]]]]];
        }
    }


    
    SKSpriteNode *endLevelLiftNode; // Ascenseur de la fin du niveau
    NSArray *endLevelLift = [group objectsNamed:@"endLevelLift"];
    for (NSDictionary *final in endLevelLift) {
        CGFloat x = [final[@"x"] floatValue];
        CGFloat y = [final[@"y"] floatValue];
        CGFloat width = [final[@"width"] floatValue];
        CGFloat height = [final[@"height"] floatValue];
        
        SKTexture *textureCaisse = [SKTexture textureWithImageNamed:@"ascenseurF-01.png"];
        endLevelLiftNode = [SKSpriteNode spriteNodeWithTexture:textureCaisse size: CGSizeMake(width, height)];
        
        endLevelLiftNode.name = @"endLevelLiftNode";
        endLevelLiftNode.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:CGSizeMake(width, height) center:CGPointMake(width/2,height/2)];
        endLevelLiftNode.physicsBody.categoryBitMask = PhysicsCategorySensors;
        endLevelLiftNode.physicsBody.friction = 0.1; // la caisse glisse
        endLevelLiftNode.anchorPoint = CGPointMake(0, 0);
        endLevelLiftNode.position = CGPointMake(x,y);
        endLevelLiftNode.zPosition = -8; // derriere caisse, alien etc.
        endLevelLiftNode.physicsBody.dynamic = NO;
        
        myFinishRectangle = [SKSpriteNode node]; // for debug purposes / pour débugger: [SKSpriteNode spriteNodeWithColor:[UIColor colorWithRed:1 green: 1                                                                                blue: 1 alpha: .5] size:CGSizeMake(6, 80)];
        myFinishRectangle.anchorPoint = CGPointMake(0.5, 0.5);
        myFinishRectangle.position = CGPointMake(endLevelLiftNode.position.x + endLevelLiftNode.size.width/2, endLevelLiftNode.position.y + endLevelLiftNode.size.height/2);
        myFinishRectangle.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:CGSizeMake(6, 80) center:CGPointMake(8, 0)];
        myFinishRectangle.physicsBody.dynamic = NO;
        myFinishRectangle.physicsBody.categoryBitMask = PhysicsCategorySensors;
        myFinishRectangle.name = @"finish";
    }

    if(myFinishRectangle) [tileMap addChild: myFinishRectangle];
    if(endLevelLiftNode) [tileMap addChild: endLevelLiftNode];
    
    // Item: for batteries and other objects / Item: pour la pile et autres objets
    NSArray *tabItem;
    if((tabItem=[group objectsNamed:@"uranium"]))
    {
        for (NSDictionary *monItem in tabItem) {
            plpItem *myItem;
            myItem = [[plpItem alloc] initAtPosition:[self convertPosition:monItem] withTexture:@"pile.png"];
            if(myItem)
            {
                myItem.name = @"uranium";
                myItem.physicsBody.categoryBitMask = PhysicsCategoryItems;
                [tileMap addChild:myItem];
            }
            else
            {
                NSLog(@"Erreur lors de la création de la pile d’uranium.");
            }
        }
    }

    // Train
    NSArray *trainObjectMarker;
    if((trainObjectMarker = [group objectsNamed:@"train"]))
    {
        plpTrain *trainNode;

        for (NSDictionary *theTrain in trainObjectMarker) {
            trainNode = [[plpTrain alloc] initAtPosition: [self convertPosition:theTrain] withMainTexture:@"Train_chassis_02.png" andWheelTexture:@"Train-roue.png"];
            //trainNode = [[plpTrain alloc] initAtPosition: [self convertPosition:theTrain] withMainTexture:@"ChariotSocle.png" andWheelTexture:@"ChariotRoue.png"];
            
            if(trainNode)
            {
                trainNode.physicsBody.categoryBitMask = PhysicsCategoryObjects;
                trainNode.physicsBody.collisionBitMask = PhysicsCategoryTiles|PhysicsCategoryObjects|PhysicsCategoryEdgar|PhysicsCategoryAliens;
                [tileMap addChild:trainNode]; // vs myLevel
                [trainNode getLeftWheel].physicsBody.collisionBitMask = PhysicsCategoryTiles|PhysicsCategoryObjects|PhysicsCategoryEdgar|PhysicsCategoryAliens;
                [trainNode getRightWheel].physicsBody.collisionBitMask = PhysicsCategoryTiles|PhysicsCategoryObjects|PhysicsCategoryEdgar|PhysicsCategoryAliens;
                
                SKPhysicsJointPin *pinGauche = [SKPhysicsJointPin jointWithBodyA:[trainNode getLeftWheel].physicsBody bodyB:trainNode.physicsBody anchor:CGPointMake(trainNode.position.x-20, trainNode.position.y-20)];
                [self.physicsWorld addJoint:pinGauche];
                
                SKPhysicsJointPin *pinDroit = [SKPhysicsJointPin jointWithBodyA:[trainNode getRightWheel].physicsBody bodyB:trainNode.physicsBody anchor:CGPointMake(trainNode.position.x+20, trainNode.position.y-20)];
                [self.physicsWorld addJoint:pinDroit];
            }
        }
    }
    
    NSArray *verticalPlatformObjectMarker;
    if((verticalPlatformObjectMarker = [group objectsNamed:@"verticalPlatform"]))
    {
        plpPlatform *verticalPlatformNode;

        /*
        Inverted coordonate system in the Tiled app and in SpriteKit.
        Tiled:
         0, 0 = upper left / coin supérieur gauche
        SriteKit:
         0, 0 = bottom left / coin inférieur gauche
        =>
        if the platform has the "moveUpFirst" property: position = x, y - height; limite = y
        otherwise: position = x, y; limite = y - height
        */
        
        
        for (NSDictionary *theVerticalPlatform in verticalPlatformObjectMarker) {
            if([theVerticalPlatform[@"moveUpFirst"] intValue] == 1)
            {
                verticalPlatformNode = [[plpPlatform alloc] initAtPosition: CGPointMake([theVerticalPlatform[@"x"] floatValue], [theVerticalPlatform[@"y"] floatValue] + [theVerticalPlatform[@"height"] floatValue]-8)
                    withSize:CGSizeMake([theVerticalPlatform[@"width"] floatValue], 8)
                    withDuration:[theVerticalPlatform[@"movementDuration"] floatValue] upToX:[theVerticalPlatform[@"x"] floatValue] andY:[theVerticalPlatform[@"y"] floatValue]];
            }else{
                verticalPlatformNode = [[plpPlatform alloc] initAtPosition: CGPointMake([theVerticalPlatform[@"x"] floatValue], [theVerticalPlatform[@"y"] floatValue])
                    withSize:CGSizeMake([theVerticalPlatform[@"width"] floatValue], 8)
                    withDuration:[theVerticalPlatform[@"movementDuration"] floatValue] upToX:[theVerticalPlatform[@"x"] floatValue] andY:[theVerticalPlatform[@"y"] floatValue] + [theVerticalPlatform[@"height"] floatValue] -8];
            }
            
            if(verticalPlatformNode)
            {
                verticalPlatformNode.physicsBody.categoryBitMask = PhysicsCategoryObjects;
                [tileMap addChild:verticalPlatformNode]; // vs myLevel
            }
        }
    }
    
    
    NSArray *platformObjectMarker;
    if((platformObjectMarker = [group objectsNamed:@"platform"]))
    {
        plpPlatform *platformNode;
        
        for (NSDictionary *thePlatform in platformObjectMarker) {
            float y_limit = [thePlatform[@"y_limit"] floatValue];
            if(!y_limit)
            {
                y_limit = [thePlatform[@"y"] floatValue];
            }
            platformNode = [[plpPlatform alloc] initAtPosition: CGPointMake([thePlatform[@"x"] floatValue], [thePlatform[@"y"] floatValue])//[self convertPosition:thePlatform]
                                               withSize:CGSizeMake([thePlatform[@"width"] floatValue], [thePlatform[@"height"] floatValue])
                                                  withDuration:[thePlatform[@"movementDuration"] floatValue] upToX:[thePlatform[@"x_limit"] floatValue] andY:y_limit];
            
            if(platformNode)
            {
                platformNode.physicsBody.categoryBitMask = PhysicsCategoryObjects;
                [tileMap addChild:platformNode];
            }
        }
    }
    
    // Aliens / Extra-terrestres
    NSArray *tabAlien;
    if((tabAlien=[group objectsNamed:@"alien1"]))
    {
        for (NSDictionary *monAlien in tabAlien) {
            plpEnemy *alien;
            alien = [[plpEnemy alloc] initAtPosition:[self convertPosition:monAlien] withSize:CGSizeMake([monAlien[@"width"] floatValue], [monAlien[@"height"] floatValue]) withMovement:[monAlien[@"moveX"] floatValue]];
            if(alien)
            {
                alien.physicsBody.categoryBitMask = PhysicsCategoryAliens;
                alien.physicsBody.collisionBitMask = PhysicsCategoryObjects | PhysicsCategoryTiles;
                
                [tileMap addChild:alien];
            }
            else
            {
                NSLog(@"Erreur lors de la création de l'alien.");
            }
        }
    }
}


- (void)pauseAction
{
    SKView *spriteView = (SKView *) self.view;
    
    if(!spriteView.paused){
        spriteView.paused = YES;
    }else{
        spriteView.paused = NO;
    }
    waitForTap = TRUE;
}

- (void)resumeAction
{
    SKView *spriteView = (SKView *) self.view;
    if(spriteView.paused){
        spriteView.paused = NO;
    }

}

- (void)EdgarDiesOf:(int)deathType
{
    //  Death count disabled in current version / Décompte des morts désactivé dans la version actuelle
    //  deathCount++;

    if(deathType == SUICIDE_DEATH)
    {
        [myFinishRectangle removeFromParent];
        myFinishRectangle = nil;
        NSLog(@"On recharge le niveau %d", nextLevelIndex);
        [self startLevel];
    }
    else
    {
        [self resetEdgar];
    }
}

- (void)resetEdgar
{
    stopRequested = TRUE;
    [Edgar removeAllActions];
    [Edgar.physicsBody setVelocity:CGVectorMake(0, 0)];
    [Edgar setPosition:startPosition];
    [Edgar setScale:1];
    [Edgar resetItem];
    [Edgar giveControl]; // ddd voir si ne fait pas doublon
    isJumping = FALSE;
    gonnaCrash = FALSE;
    moveLeft = FALSE;
    moveRight = FALSE;
    moveUpRequested = FALSE;
    moveLeftRequested = FALSE;
    moveRightRequested = FALSE;
    listensToContactEvents = TRUE;
    [myLevel childNodeWithName:@"uranium"].hidden = FALSE;
}

- (void)getsPaused
{
    [Edgar removeControl];
    [self doVolumeFade];
}

-(void)resumeAfterPause
{
    [Edgar giveControl];
    if(self.audioPlayer != nil)
    {
        [self.audioPlayer play];
    }
}


// This method is called just after update, befor rendering the scene
- (void)didSimulatePhysics
{
    // New code with SKCameraNode, added in iOS 9
    //    NSLog(@"Position: %f", myCamera.position.x);
    
    // Explanation about how to fix "gap" problems: http://stackoverflow.com/questions/24921017/spritekit-nodes-adjusting-position-a-tiny-bit
    
    
    if(1==2)//fixedCamera==TRUE)
    {
        myCamera.position = Edgar.position;
    }
    else
    {
        // We move the camera when Edgar is close from the edge / On bouge la vue quand Edgar approche du bord du cadre:
        CGFloat xDistance = Edgar.position.x - myCamera.position.x; // gets > 0 if Edgar moves right
        CGFloat yDistance = Edgar.position.y - myCamera.position.y;
        CGPoint newCameraPosition = myCamera.position;
        
        if(xDistance < -100) // a gauche
        {
            newCameraPosition.x = Edgar.position.x + 100;
            [myCamera setPosition:CGPointMake(newCameraPosition.x, myCamera.position.y)];
        }
        else if(xDistance > 100) // a droite
        {
            newCameraPosition.x = Edgar.position.x - 100;
            [myCamera setPosition:CGPointMake(newCameraPosition.x, myCamera.position.y)];
        }
        if(yDistance < -100)
        {
            newCameraPosition.y = Edgar.position.y + 100;
            [myCamera setPosition:CGPointMake(myCamera.position.x, newCameraPosition.y)];
        }
        else if(yDistance > 100)
        {
            newCameraPosition.y = Edgar.position.y - 100;
            [myCamera setPosition:CGPointMake(myCamera.position.x, newCameraPosition.y)];
        }
        myCamera.position = CGPointMake(roundf(newCameraPosition.x), roundf(newCameraPosition.y));
    }
    /*
     Detect if Edgar will crash -- currently disabled
     if(![Edgar.physicsBody isResting]){
     if(Edgar.physicsBody.velocity.dy < -1400){
     gonnaCrash = TRUE;
     }
     }*/
    
    
 /*
    Old code without SKCameraNode
    CGPoint edgarPosition = Edgar.position;

    

    if(fixedCamera==TRUE)
    {
        myWorld.position = CGPointMake(-(edgarPosition.x-(self.size.width/2)), -(edgarPosition.y-(self.size.height/2)));
    }
    else
    {
        
        CGPoint worldPosition = myWorld.position;
        CGFloat xCoordinate = worldPosition.x + edgarPosition.x;
        CGFloat yCoordinate = worldPosition.y + edgarPosition.y;
        
        // Explanation about how to fix "gap" problems: http://stackoverflow.com/questions/24921017/spritekit-nodes-adjusting-position-a-tiny-bit
        

        
        if(Edgar.physicsBody.velocity.dy < -560) // La vue «glisse» si Edgar tombe de haut
        {
            worldPosition.y = -(Edgar.position.y-200); // 200 = self.size.height/2
        }
        
        // We move the camera when Edgar is close from the edge / On bouge la vue quand Edgar approche du bord du cadre:
        
        if(xCoordinate < 300) // a gauche
        {
            worldPosition.x =  worldPosition.x - xCoordinate + 300;
        }
        else if(xCoordinate > 500) // a droite
        {
            worldPosition.x = worldPosition.x + 500 - xCoordinate; // 500 = self.frame.size.width - 300
        }
        if(yCoordinate < 100) // && worldPosition.y < 600) // en bas
        {
            worldPosition.y = 200 - edgarPosition.y;  // au depart: worldPosition.y + 335;
        }
        else if(yCoordinate > 330)
        {
            worldPosition.y = 200 - edgarPosition.y; // depassement en haut. Au depart: worldPosition.y - 335;
        }
        else if(yCoordinate < 30)
        {
            [self EdgarDiesOf:FALLEN_DEATH];
        }
        
        myWorld.position = CGPointMake(roundf(worldPosition.x), roundf(worldPosition.y));
    }*/
}

- (void)doVolumeFade
{
    if (self.audioPlayer.volume > 0.1) {
        self.audioPlayer.volume = self.audioPlayer.volume - 0.1;
        [self performSelector:@selector(doVolumeFade) withObject:nil afterDelay:0.1];
    } else {
        // Stop and get the sound ready for playing again
        [self.audioPlayer stop];
        self.audioPlayer.currentTime = 0;
        [self.audioPlayer prepareToPlay];
        self.audioPlayer.volume = 1.0;
    }
}

-(void)startLevel{
    [myLevel removeFromParent];
    [Edgar removeFromParent];
    [self resetEdgar];
    
    if((nextLevelIndex == LAST_LEVEL_INDEX) && (self.audioPlayer != nil))
    {
        [self doVolumeFade];
    }
    
    myLevel = [self loadLevel:nextLevelIndex];
    
    myWorld.position = CGPointMake(0, 0);
    [myWorld addChild: myLevel];
    
    [self addStoneBlocks:myLevel];
    [self loadAssets:myLevel]; // charge la position d'Edgar
    [myWorld runAction:[SKAction fadeAlphaTo:1 duration:1.0]];
    Edgar.position = startPosition;
    myCamera.position = startPosition;

    [myLevel addChild: Edgar];
    
    SKPhysicsJointFixed *pinEdgar = [SKPhysicsJointFixed jointWithBodyA:Edgar.physicsBody bodyB:Edgar->rectangleNode.physicsBody anchor:CGPointMake(Edgar.position.x, Edgar.position.y)];
    [self.physicsWorld addJoint:pinEdgar];
    
    [Edgar giveControl];
//    [Edgar addLight]; -> It works! :-)
}

- (void) didBeginContact:(SKPhysicsContact *)contact
{
    SKNode *contactNode = contact.bodyA.node;
    
    if(!listensToContactEvents)
    {
        return;
    }

    if(isJumping==TRUE)
    {
        if([contactNode isKindOfClass:[plpHero class]] || [contact.bodyB.node isKindOfClass:[plpHero class]])
        {
            isJumping = FALSE;
        }
    }
    
    if(contactNode.physicsBody.categoryBitMask == PhysicsCategoryEdgar)
    {
        contactNode = contact.bodyB.node;
    }else{
        if(contact.bodyB.node.physicsBody.categoryBitMask != PhysicsCategoryEdgar)
        {
            return; // It means Edgar isn't involved / Edgar n'est pas impliqué
        }
    }
    
    if(willLoseContextVelocity==TRUE)
    {
        contextVelocityX = 0;
        willLoseContextVelocity = FALSE;
    }

    if(contactNode.physicsBody.categoryBitMask == PhysicsCategorySensors)
    {
        if([contactNode.name isEqualToString:@"endLevelLiftNode"] && [Edgar hasItem])
        {
            SKAction *greenDoor = [SKAction setTexture:[SKTexture textureWithImageNamed:@"ascenseurO-01.png"]];
            [contactNode runAction:greenDoor];
        }
        
        if([contactNode.name isEqualToString:@"finish"])
        {
            if([Edgar hasItem])
            {
                [Edgar removeControl];
                [Edgar runAction: [SKAction sequence:@[[SKAction moveToX:myFinishRectangle.position.x duration: .2], [SKAction runBlock:^{
                    stopRequested = TRUE;
                }]]]];
                [myFinishRectangle removeFromParent];
                myFinishRectangle = nil;
                nextLevelIndex++;
                NSLog(@"Chargement du niveau %d", nextLevelIndex);
                id fade = [SKAction fadeAlphaTo:0 duration:1];
                id wait = [SKAction waitForDuration:.5];
                id run = [SKAction runBlock:^{
                    [self startLevel];
                }];
                [myWorld runAction:[SKAction sequence:@[wait, fade, wait, run]]];
            }
        }
        
        if(nextLevelIndex==LAST_LEVEL_INDEX)
        {
            if([contactNode.name isEqualToString:@"finalAnimationSensor"])
            {
                [contactNode removeFromParent];
                [Edgar removeControl];
//                fixedCamera = TRUE;
                if(!moveRight)
                {
                    moveRightRequested = TRUE;
                }
                NSURL *url = [[NSBundle mainBundle] URLForResource:@"Sounds/EndGame" withExtension:@"mp3"];
                NSError *error = nil;
                
                if(self.audioPlayer != nil)
                {
                    [self.audioPlayer stop];
                }
                self.audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&error];
                
                if (!self.audioPlayer) {
                    NSLog(@"Error creating player: %@", error);
                }
                
                [self.audioPlayer play];
                
                
                SKNode *alienVessel;
                alienVessel = [SKSpriteNode spriteNodeWithImageNamed:@"UFO1-02.png"];
                alienVessel.name = @"alienVessel";

                SKSpriteNode *beam = [SKSpriteNode spriteNodeWithImageNamed:@"rayonb.png"];
                beam.alpha = 0;

                CGPoint referencePoint = CGPointMake(Edgar.position.x + 600, Edgar.position.y + 266);
                CGPoint referencePointAlien = CGPointMake(Edgar.position.x + 600, Edgar.position.y + 126);
                
                SKAction *waitAction = [SKAction waitForDuration: 1];
                SKAction *longWaitAction = [SKAction waitForDuration: 2];
                
                SKAction *fixedCameraAction = [SKAction runBlock:^{
                    NSLog(@"Caméra fixée");
                    fixedCamera = TRUE;
                }];
                
                SKAction *createAlien = [SKAction runBlock:^{
                    alienVessel.position = CGPointMake(Edgar.position.x, Edgar.position.y+400);
                    [myLevel addChild: alienVessel];
                    
                    [alienVessel addChild: beam];
                    beam.position = CGPointMake(0, -50);
                    beam.zPosition = -12;

                    NSLog(@"alien vessel added");
                }];
                
                SKAction *moveAlien = [SKAction runAction:[SKAction moveTo:referencePointAlien duration:2] onChildWithName:@"//alienVessel"];
                moveAlien.timingMode = SKActionTimingEaseInEaseOut;
                
                SKAction *moveAlien2 = [SKAction runAction:[SKAction moveByX: 0 y: 100 duration:2] onChildWithName:@"//alienVessel"];
                moveAlien2.timingMode = SKActionTimingEaseInEaseOut;
                
/*                SKAction *alienSpeed = [SKAction runBlock:^{
                    [alienVessel.physicsBody setVelocity:Edgar.physicsBody.velocity];
                }];*/
                
                SKAction *showBeam = [SKAction runAction:[SKAction fadeAlphaTo:1 duration:0] onChildWithName:@"beam"];
                
                SKAction *createBeam = [SKAction runBlock:^{
                    [beam setAlpha: 1.0f];
                    [Edgar removeActionForKey:@"bougeDroite"];
                    [Edgar removeActionForKey:@"walkingInPlaceEdgar"];
                    [Edgar.physicsBody setVelocity: CGVectorMake(0, 0)];
                    Edgar.physicsBody.affectedByGravity = 0;
                    [Edgar->rectangleNode removeFromParent];    // => interdire de recommencer la scène, ou ça va planter
                }];
                
                SKAction *moveEdgar = [SKAction runAction:[SKAction moveTo:referencePoint duration:2] onChildWithName:@"//Edgar"];
                moveEdgar.timingMode = SKActionTimingEaseInEaseOut;
                
                SKAction *flyAway = [SKAction runAction:[SKAction moveTo:CGPointMake(2000, 2000) duration:1] onChildWithName:@"//alienVessel"];
                flyAway.timingMode = SKActionTimingEaseIn;
                SKAction *vanish = [SKAction runAction:[SKAction fadeAlphaTo:0 duration:0] onChildWithName:@"//Edgar"];
                SKAction *removeBeam = [SKAction runBlock:^{
                    [beam removeFromParent];
                }];
                
                SKAction *theScale = [SKAction scaleTo:1.5 duration:2];
                [myCamera runAction: theScale];
                
                SKAction *finalMessage = [SKAction runBlock:^{
                    UITextView *finalMessageTextView = [[UITextView alloc] init];
                    // add the final time here
                    finalMessageTextView.text = @"You succeeded! \nHowever, the alien vessel wasn’t part of the plan. \nStay tuned for the next part.\n\nMore information on the «Edgar The Explorer» Facebook page.\nThis is a Creative Commons and GLP game. Our assets and source code are freely available on GitHub (search for: Edgar The Explorer).";
                    finalMessageTextView.textColor = [UIColor whiteColor];
                    finalMessageTextView.backgroundColor = [UIColor colorWithRed:.349f green:.259f blue:.447f alpha:1];
                    finalMessageTextView.editable = NO;
                    [finalMessageTextView setFont:[UIFont fontWithName:@"Gill Sans" size:16]];
                    [finalMessageTextView setFrame: CGRectMake(50, 50, self.view.bounds.size.width-100, self.view.bounds.size.height-100)];
                    
                    UIButton *myButton  =   [UIButton buttonWithType:UIButtonTypeRoundedRect];
                    myButton.frame      =   CGRectMake(270.0, 210.0, 50.0, 30.0);
                    [myButton setBackgroundColor: [UIColor whiteColor]];

                    [myButton setTitleColor: [UIColor colorWithRed:.349f green:.259f blue:.447f alpha:1] forState:UIControlStateNormal];
                    [[myButton layer] setMasksToBounds:YES];
                    [[myButton layer] setCornerRadius:5.0f];
                    
/*                    [[myButton layer] setBorderWidth:2.0f];
                    [[myButton layer] setBorderColor:[UIColor greenColor].CGColor];*/
                    
                    [myButton setTitle: @"OK" forState:UIControlStateNormal];
                    [myButton addTarget: self
                              action: @selector(inGameButtonClicked:)
                    forControlEvents: UIControlEventTouchUpInside];
                    
                    [self.view addSubview:finalMessageTextView];
                    [self.view addSubview:myButton];
                }];
                
                [myLevel runAction:[SKAction sequence:@[waitAction, fixedCameraAction, [SKAction scaleTo:1 duration:1], longWaitAction, createAlien, moveAlien, longWaitAction, createBeam, showBeam, moveEdgar, longWaitAction, vanish, removeBeam, moveAlien2, longWaitAction, flyAway, finalMessage]]];
                
                
            }
        }else if(nextLevelIndex==0)
        {
            SKSpriteNode *helpNode;
            
            // First we remove any precedent help image
            if((helpNode = (SKSpriteNode*)[myCamera childNodeWithName:@"helpNode"]))
            {
                [helpNode removeFromParent];
                helpNode = nil;
                NSLog(@"Contact avec nouveau senseur -> helpNode retiré");
//                [[self childNodeWithName:@"helpNode"] removeFromParent];
            }
            
            if([contactNode.name isEqualToString:@"walk"])
            {
                helpNode = [SKSpriteNode spriteNodeWithImageNamed:@"swipeRight.png"];
            }else if([contactNode.name isEqualToString:@"jump"])
            {
                helpNode = [SKSpriteNode spriteNodeWithImageNamed:@"swipeJump.png"];
            }else if([contactNode.name isEqualToString:@"goUpstairs"])
            {
                helpNode = [SKSpriteNode spriteNodeWithImageNamed:@"swipeJump.png"];
            }else if([contactNode.name isEqualToString:@"showUranium"])
            {
                helpNode = [SKSpriteNode spriteNodeWithImageNamed:@"showUranium.png"];
            }
            
            if(helpNode)
            {
                helpNode.name = @"helpNode";
                helpNode.size=CGSizeMake(578, 245);
                helpNode.position = CGPointMake(0.0f, 0.0f);
//                helpNode.alpha = 0.4;
                [myCamera addChild: helpNode];
                
                [helpNode runAction: [SKAction fadeAlphaBy:0 duration: 5]];
                
                NSLog(@"HelpNode créé. On retire le senseur.");
            }else{
                NSLog(@"Pas de nom de senseur correspondant");
            }

        }
    }
    
    if(contactNode.physicsBody.categoryBitMask == PhysicsCategoryItems)
    {
        if([contactNode isKindOfClass:[plpItem class]]) // à simplifier
        {
            [Edgar takeItem];
            [myLevel childNodeWithName:@"uranium"].hidden = YES;
//            [(plpItem *)contactNode removeFromParent]; <- if there is a need to remove the item
        }
    }
    
    
    if(contactNode.physicsBody.categoryBitMask == PhysicsCategoryObjects)
    {
        if([contactNode isKindOfClass:[plpTrain class]])
        {
            plpTrain *theTrain = (plpTrain *)contactNode;
            [theTrain setHeroAbove];
            [(plpTrain *)contactNode accelerateAtRate:5 toMaxSpeed:200 invertDirection:FALSE];
            return;
        }

        if([contactNode isKindOfClass:[plpPlatform class]])
        {
//            NSLog(@"Edgar : %f, plateforme: %f", Edgar.position.y - 42, contactNode.position.y);
            if(Edgar.position.y - 42 > contactNode.position.y){ /// ddd verifier hauteur
                if([Edgar hasControl]){
                }
                [(plpPlatform *)contactNode setHeroAbove];
            }
        }
    }
    
    if(contactNode.physicsBody.categoryBitMask == PhysicsCategoryAliens)
    {
        if([contactNode isKindOfClass:[plpEnemy class]])
        {
            if(![Edgar alreadyInfected])
            {
                if(!bougeDroite && !bougeGauche) // essai pour éviter l'immobilisation
                {
                    moveRightRequested = TRUE;
                }
                [Edgar getsInfected];
            }
        }
    }
}

-(void)didEndContact:(SKPhysicsContact *)contact
{
    SKNode *contactNode = contact.bodyA.node;

    
    if(contactNode.physicsBody.categoryBitMask == PhysicsCategoryEdgar)
    {
        contactNode = contact.bodyB.node;
    }else{
        if(contact.bodyB.node.physicsBody.categoryBitMask != PhysicsCategoryEdgar)
        {
            return; // It means Edgar isn't involved / Edgar n'est pas impliqué
        }
    }
    
    if(contactNode.physicsBody.categoryBitMask == PhysicsCategoryObjects)
    {
        if([contactNode isKindOfClass:[plpTrain class]])
        {
            NSLog(@"Quitte le train => [plus de] décélération");
            [(plpTrain *)contactNode decelerateAtRate:15];
            [(plpTrain *)contactNode HeroWentAway];
            willLoseContextVelocity = TRUE;
            return;
        }
        
        if([contactNode isKindOfClass:[plpPlatform class]])
        {
            [(plpPlatform *)contactNode HeroWentAway];
            willLoseContextVelocity = TRUE; // ou pour effet immédiat:  contextVelocityX = 0;
        }
    }
    
    if(nextLevelIndex==0) // Tutorial
    {
        if(contactNode.physicsBody.categoryBitMask == PhysicsCategorySensors)
        {
            SKNode* helpNode;
            
            if((helpNode = (SKSpriteNode*)[myCamera childNodeWithName:@"helpNode"]))
            {
                [helpNode removeFromParent];
                helpNode = nil;
                [contactNode removeFromParent]; // We remove the sensor / On enlève le senseur
            }
        }
    }
}

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    // On detecte les mouvements et la position du personnage avant de transmettre à update().
    // We get touches events before the update() function.


    
    if([Edgar hasControl]==TRUE) // && spriteView.paused == NO => plutot: faire variable plus globale
    {
        for (UITouch *touch in touches) {
            
            CGPoint location = [touch locationInNode:self];
            
            // Contrôles alternatifs pour le simulateur iOS | Alternate controls for the iOS simulator
            if(USE_ALTERNATE_CONTROLS==1)
            {
                if(!moveLeft && !moveRight)
                {
                    if(location.x > 400)
                    {
                        moveRightRequested = true;
                    } else if (location.x < 400){
                        moveLeftRequested = true;
                    }
                    ignoreNextTap = TRUE;
                }
            }

            touchStartPosition = location; //location;// [touch locationInView:self.view];

            if(touch.tapCount == 4)
            {
//                SKView *spriteView = (plpViewController *) self.view;
//                [self.viewcontroller addButton];

//                [spriteView addButton];
                 
                if(!self.view.showsPhysics)
                {
                    self.view.showsPhysics = YES;
                    self.view.showsFPS = YES;
                }
                else
                {
                    self.view.showsPhysics = NO;
                    self.view.showsFPS = NO;
                }
            }
            else if(touch.tapCount == 5) // Raccourci vers le niveau suivant | Shortcut to the next level
            {
                [myFinishRectangle removeFromParent];
                myFinishRectangle = nil;
                nextLevelIndex++;
                self.view.showsPhysics = NO;
                self.view.showsFPS = NO;

                NSLog(@"Chargement du niveau %d", nextLevelIndex);
                [self startLevel];
            }
            else if(touch.tapCount == 6)
            {
                [myFinishRectangle removeFromParent];
                myFinishRectangle = nil;
                nextLevelIndex = 6;
                self.view.showsPhysics = NO;
                self.view.showsFPS = NO;
                
                [self startLevel];
            }
        }
    }
}

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    if([Edgar hasControl]){
        for (UITouch *touch in touches) {
            CGPoint endPosition = [touch locationInNode:self];

            if(endPosition.y - 10 > touchStartPosition.y)
            {
                moveUpRequested = TRUE;
            }
/*            else if (endPosition.y + 10 < touchStartPosition.y)
            {
                stopRequested = TRUE; // trop court
            }*/
            
            if(endPosition.x -5 > touchStartPosition.x)
            {
                moveRightRequested = TRUE;
            }
            else if(endPosition.x + 5 < touchStartPosition.x)
            {
                moveLeftRequested = TRUE;
            }
            
            if((!moveUpRequested)&&(!moveLeftRequested)&&(!moveRightRequested))
            {
                stopRequested = TRUE;
            }

            // Contrôles alternatifs pour le simulateur iOS | Alternate controls for the iOS simulator
            if(USE_ALTERNATE_CONTROLS==1)
            {
                if((ignoreNextTap==FALSE) && (moveLeft || moveRight))
                {
                    if(endPosition.x > 400)
                    {
                        moveRightRequested = true;
                    } else if (endPosition.x < 400){
                        moveLeftRequested = true;
                    }
                }else{
                    ignoreNextTap = FALSE;
                }
            }
        }
    }
}

-(void)update:(CFTimeInterval)currentTime {
    
    // Mouvements
    
    if(stopRequested == TRUE && !isJumping){
        stopRequested = FALSE;
        moveLeft = FALSE;
        moveRight = FALSE;
        moveRightRequested = FALSE;
        moveLeftRequested = FALSE;
        Edgar.xScale = 1.0;
        [Edgar.physicsBody setVelocity: CGVectorMake(0 + contextVelocityX, Edgar.physicsBody.velocity.dy)];
        [Edgar facingEdgar];
        [Edgar removeActionForKey:@"bougeDroite"];
        [Edgar removeActionForKey:@"bougeGauche"];
        [Edgar removeActionForKey:@"walkingInPlaceEdgar"];
    }
    
    if (moveRightRequested == TRUE && !isJumping){
        moveRightRequested = false;
        if((moveRight!=TRUE) || moveUpRequested){
            Edgar.xScale = 1.0;
            [Edgar removeAllActions];
            [Edgar walkingEdgar];
            [Edgar runAction:bougeDroite2 withKey:@"bougeDroite"];
            moveRight = TRUE;
            moveLeft = FALSE;
        }else{
            // il s'arrete
            stopRequested = TRUE;
        }
    }else if (moveLeftRequested == true && !isJumping){
        moveLeftRequested = false;
        if((moveLeft != TRUE) || moveUpRequested){
            Edgar.xScale = -1.0;
            [Edgar removeAllActions];
            [Edgar walkingEdgar];
            [Edgar runAction: bougeGauche2 withKey:@"bougeGauche"];
            moveLeft = true;
            moveRight = false;
        }else{
            // il s'arrete
            stopRequested = TRUE;
        }
    }

    if (moveUpRequested == true && !isJumping){
        moveUpRequested = false;
        isJumping = TRUE;
        [Edgar.physicsBody applyImpulse: CGVectorMake(0, 48000)]; // auparavant 50000 puis 45000
        if(moveLeft||moveRight)
        {
            [Edgar jumpingEdgar];
        }

    }
}

@end
