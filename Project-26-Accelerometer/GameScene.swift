//
//  GameScene.swift
//  Project-26-Accelerometer
//
//  Created by Serhii Prysiazhnyi on 28.11.2024.
//

import CoreMotion
import SpriteKit
import GameplayKit

enum CollisionTypes: UInt32 {
    case player = 1
    case wall = 2
    case star = 4
    case vortex = 8
    case finish = 16
    case teleport = 32
}

class GameScene: SKScene, SKPhysicsContactDelegate {
    
    var player: SKSpriteNode!
    var lastTouchPosition: CGPoint?
    var motionManager: CMMotionManager!
    
    var scoreLabel: SKLabelNode!

    var score = 0 {
        didSet {
            scoreLabel.text = "Score: \(score)"
        }
    }
    
    var isGameOver = false
    var freePositions = [CGPoint]()
    var level = 1
    
    override func didMove(to view: SKView) {
        
        let background = SKSpriteNode(imageNamed: "background.jpg")
        background.position = CGPoint(x: 512, y: 384)
        background.blendMode = .replace
        background.zPosition = -1
        addChild(background)
        
        loadLevel()
        createPlayer()
        
        physicsWorld.gravity = .zero
        
        motionManager = CMMotionManager()
        motionManager.startAccelerometerUpdates()
        
        scoreLabel = SKLabelNode(fontNamed: "Chalkduster")
        scoreLabel.text = "Score: 0"
        scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.position = CGPoint(x: 16, y: 16)
        scoreLabel.zPosition = 2
        addChild(scoreLabel)
        
        physicsWorld.contactDelegate = self
        }
    
    func loadLevel() {
        print("loadLevel - \(level)")
        guard let levelURL = Bundle.main.url(forResource: "level\(level)", withExtension: "txt") else {
            level = 1
            fatalError("Could not find level1.txt in the app bundle.")
            
        }
        guard let levelString = try? String(contentsOf: levelURL) else {
            fatalError("Could not load level1.txt from the app bundle.")
        }

        let lines = levelString.components(separatedBy: "\n")

        for (row, line) in lines.reversed().enumerated() {
            for (column, letter) in line.enumerated() {
                let position = CGPoint(x: (64 * column) + 32, y: (64 * row) - 32)

                if letter == "x" {
                    // load wall
                    let node = SKSpriteNode(imageNamed: "block")
                    node.position = position

                    node.physicsBody = SKPhysicsBody(rectangleOf: node.size)
                    node.physicsBody?.categoryBitMask = CollisionTypes.wall.rawValue
                    node.physicsBody?.isDynamic = false
                    addChild(node)
                } else if letter == "v"  {
                    // load vortex
                    let node = SKSpriteNode(imageNamed: "vortex")
                    node.name = "vortex"
                    node.position = position
                    node.run(SKAction.repeatForever(SKAction.rotate(byAngle: .pi, duration: 1)))
                    node.physicsBody = SKPhysicsBody(circleOfRadius: node.size.width / 2)
                    node.physicsBody?.isDynamic = false

                    node.physicsBody?.categoryBitMask = CollisionTypes.vortex.rawValue
                    node.physicsBody?.contactTestBitMask = CollisionTypes.player.rawValue
                    node.physicsBody?.collisionBitMask = 0
                    addChild(node)
                } else if letter == "s"  {
                    // load star
                    let node = SKSpriteNode(imageNamed: "star")
                    node.name = "star"
                    node.physicsBody = SKPhysicsBody(circleOfRadius: node.size.width / 2)
                    node.physicsBody?.isDynamic = false

                    node.physicsBody?.categoryBitMask = CollisionTypes.star.rawValue
                    node.physicsBody?.contactTestBitMask = CollisionTypes.player.rawValue
                    node.physicsBody?.collisionBitMask = 0
                    node.position = position
                    addChild(node)
                } else if letter == "f"  {
                    // load finish
                    let node = SKSpriteNode(imageNamed: "finish")
                    node.name = "finish"
                    node.physicsBody = SKPhysicsBody(circleOfRadius: node.size.width / 2)
                    node.physicsBody?.isDynamic = false

                    node.physicsBody?.categoryBitMask = CollisionTypes.finish.rawValue
                    node.physicsBody?.contactTestBitMask = CollisionTypes.player.rawValue
                    node.physicsBody?.collisionBitMask = 0
                    node.position = position
                    addChild(node)
                } else if letter == "g"  {
                    // load teleport
                    let node = SKSpriteNode(imageNamed: "teleport")
                    node.name = "teleport"
                   //node.physicsBody = SKPhysicsBody(rectangleOf: node.size)
                    node.physicsBody = SKPhysicsBody(circleOfRadius: node.size.width / 2)
                    node.physicsBody?.isDynamic = false

                    // Устанавливаем уникальную категорию для телепорта
                    node.physicsBody?.categoryBitMask = CollisionTypes.vortex.rawValue // Или создайте новую категорию: .teleport
                    node.physicsBody?.contactTestBitMask = CollisionTypes.player.rawValue
                    node.physicsBody?.collisionBitMask = 0 // Без физических столкновений
                    node.position = position
                    addChild(node)
                } else if letter == " " {
                    // Пустая клетка: добавляем позицию в массив свободных позиций
                    freePositions.append(position)
                } else {
                    fatalError("Unknown level letter: \(letter)")
                }
            }
        }
    }

    func createPlayer() {
        player = SKSpriteNode(imageNamed: "player")
        player.position = CGPoint(x: 96, y: 672)
        player.zPosition = 1
        player.physicsBody = SKPhysicsBody(circleOfRadius: player.size.width / 2)
        player.physicsBody?.allowsRotation = false
        player.physicsBody?.linearDamping = 0.5

        player.physicsBody?.categoryBitMask = CollisionTypes.player.rawValue
        player.physicsBody?.contactTestBitMask = CollisionTypes.star.rawValue | CollisionTypes.vortex.rawValue | CollisionTypes.finish.rawValue
        player.physicsBody?.collisionBitMask = CollisionTypes.wall.rawValue
        addChild(player)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        lastTouchPosition = location
        
        if isGameOver {
            let hitNodes = nodes(at: location).filter { $0.name == "startNewGameButton" }
            
            if let _ = hitNodes.first {
                // Перезапускаем игру, если нажата кнопка
                newGame()
                // стоп музыка
//                func stopBackgroundMusic() {
//                    audioPlayer?.stop()
//                }
            }
        }
        
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        lastTouchPosition = location
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        lastTouchPosition = nil
    }
    
    override func update(_ currentTime: TimeInterval) {
        guard isGameOver == false else { return }

        #if targetEnvironment(simulator)
            if let currentTouch = lastTouchPosition {
                let diff = CGPoint(x: currentTouch.x - player.position.x, y: currentTouch.y - player.position.y)
                physicsWorld.gravity = CGVector(dx: diff.x / 100, dy: diff.y / 100)
            }
        #else
            if let accelerometerData = motionManager.accelerometerData {
                physicsWorld.gravity = CGVector(dx: accelerometerData.acceleration.y * -50, dy: accelerometerData.acceleration.x * 50)
            }
        #endif
    }
    
    func didBegin(_ contact: SKPhysicsContact) {
        guard let nodeA = contact.bodyA.node else { return }
        guard let nodeB = contact.bodyB.node else { return }

        if nodeA == player {
            playerCollided(with: nodeB)
        } else if nodeB == player {
            playerCollided(with: nodeA)
        }
    }
    
    func playerCollided(with node: SKNode) {
        if node.name == "vortex" {
            player.physicsBody?.isDynamic = false
            isGameOver = true
            score -= 1
            
            let move = SKAction.move(to: node.position, duration: 0.25)
            let scale = SKAction.scale(to: 0.0001, duration: 0.25)
            let remove = SKAction.removeFromParent()
            let sequence = SKAction.sequence([move, scale, remove])
            
            player.run(sequence) { [weak self] in
                self?.createPlayer()
                self?.isGameOver = false
            }
        } else if node.name == "star" {
            node.removeFromParent()
            score += 1
        } else if node.name == "finish" {
            
                    isGameOver = true
                    player.physicsBody?.isDynamic = false
                    level += 1
                    // Эффект исчезновения и появления
                    let move = SKAction.move(to: node.position, duration: 0.25)
                    let scale = SKAction.scale(to: 0.0001, duration: 0.25)
                    let remove = SKAction.removeFromParent()
                    let sequence = SKAction.sequence([move, scale, remove])
                    
            player.run(sequence) {
                self.showCustomAlert() // Показать алерт только после завершения анимации
            }
        } else if node.name == "teleport" {
            // Логика для телепорта
                 if let physicsBody = player.physicsBody {
                     // Сбрасываем скорость игрока и его направление
                     physicsBody.velocity = .zero
                     // Находим случайную свободную позицию для телепортации
                     if let randomPosition = freePositions.randomElement() {
                         // Эффект исчезновения и появления
                         let fadeOut = SKAction.fadeOut(withDuration: 0.25)
                         let moveToRandom = SKAction.move(to: randomPosition, duration: 0.5)
                         let fadeIn = SKAction.fadeIn(withDuration: 0.25)
                         let sequence = SKAction.sequence([fadeOut, moveToRandom, fadeIn])
                         
                         // Перемещаем игрока на новое место
                         player.run(sequence)
                }
            }
        }
    }
    
    func showCustomAlert() {
        // Создаем фон для окна оповещения
        let alertBackground = SKSpriteNode(color: .black, size: CGSize(width: 400, height: 200))
        alertBackground.position = CGPoint(x: size.width / 2, y: size.height / 2)
        alertBackground.alpha = 0.8  // Прозрачность фона
        alertBackground.zPosition = 1000  // Слой поверх других элементов
        addChild(alertBackground)
        
        // Создаем текст с результатами игры
        let scoreLabel = SKLabelNode(fontNamed: "Chalkduster")
        scoreLabel.fontSize = 30
        scoreLabel.text = "Your score: \(score)"
        scoreLabel.position = CGPoint(x: 0, y: 40)
        scoreLabel.zPosition = 1001
        alertBackground.addChild(scoreLabel)
        
        // Создаем текст с предложением начать игру заново
        let messageLabel = SKLabelNode(fontNamed: "Chalkduster")
        messageLabel.fontSize = 20
        messageLabel.text = "Press Start to New Game"
        messageLabel.position = CGPoint(x: 0, y: -20)
        messageLabel.zPosition = 1001
        alertBackground.addChild(messageLabel)
        
        // Создаем кнопку для начала новой игры
        let button = SKSpriteNode(color: .green, size: CGSize(width: 200, height: 50))
        button.position = CGPoint(x: 0, y: -70)
        button.zPosition = 1001
        button.name = "startNewGameButton"  // Добавляем имя кнопке для упрощенного обнаружения
        alertBackground.addChild(button)
        
        // Добавляем текст на кнопку
        let buttonText = SKLabelNode(fontNamed: "Chalkduster")
        buttonText.fontSize = 20
        buttonText.text = "Start Next level\(level)"
        buttonText.position = CGPoint(x: 0, y: 0)
        buttonText.zPosition = 1002
        button.addChild(buttonText)
    }
    
    func newGame() {
        print("restartGame - \(level)")  // Печатает текущий уровень, на котором закончена игра
        let newScene = GameScene(size: self.size)  // Новый экземпляр GameScene
        newScene.level = self.level  // Передаем текущий уровень
        newScene.scaleMode = self.scaleMode

        let transition = SKTransition.fade(withDuration: 1.0)
        self.view?.presentScene(newScene, transition: transition)
    }

}
