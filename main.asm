.data
    # DATA
    scoreChar: .word '0'
    peopleState: .word 'U'  # People's state, 'U' for up, 'D' for down
    randomNum: .word 0  # Random number generated
    genID: .word 0  # ID of the generator
    seed: .word 0  # Seed of the generator

    # FIFO QUEUE
    fifoQueue:
        # x, y, color, size
        .word 0 : 256
    queueHead: .word 0
    queueEnd: .word 0

    # STRINGS
    welcomePrompt: .asciiz "==== Welcome to DON'T TOUCH RED BLOCK! ==== \n"
    askPrompt: .asciiz ">>> Do you want to play? 'Y' for yes, 'Q' for quit.\n"
    playPrompt: .asciiz "\n==== Play ====\n"
    exitPrompt: .asciiz "\n==== Exit! ====\n"
    winPrompt: .asciiz ">>> Congratulations, YOU WIN!\n"  # Win prompt
    losePrompt: .asciiz ">>> Oops, YOU LOSE!\n"  # Lose prompt

    # CONTROL
    peopleFlushTime: .word 20  # ms
    blockFlushTime: .word 40  # ms
    blockSpeed: .word 32  # Decrease x by 32 each time for block movement
    triggerPosition: .word 100  # Trigger when block's x ?? 100
    blockDisappearDelay: .word 0  # Block disappears after 10ms
    upBlockY: .word 60  # Y parameter for block at the top
    downBlockY: .word 160  # Y parameter for block at the bottom
    winScoreChar: .word '3'  # Score needed to win
    mainLoopLimit: .word 50  # Main loop iterations (game duration limit)

    # COLOR TABLE
    colorTable:
        .word 'B', 0x000000ff  # Blue
        .word 'G', 0x0000ff00  # Green
        .word 'R', 0x00ff0000  # Red
        .word 'Y', 0x00ffff00  # Yellow
        .word 'W', 0x00ffffff  # White
        .word '0', 0x00000000  # Black

    # Status register bits
    EXC_ENABLE_MASK: .word 0x00000001

    # Cause register bits
    EXC_CODE_MASK: .word 0x0000003c  # Exception code bits

    EXC_CODE_INTERRUPT: .word 0  # External interrupt
    EXC_CODE_ADDR_LOAD: .word 4  # Address error on load
    EXC_CODE_ADDR_STORE: .word 5  # Address error on store
    EXC_CODE_IBUS: .word 6  # Bus error instruction fetch
    EXC_CODE_DBUS: .word 7  # Bus error on load or store
    EXC_CODE_SYSCALL: .word 8  # System call
    EXC_CODE_BREAKPOINT: .word 9  # Break point
    EXC_CODE_RESERVED: .word 10  # Reserved instruction code
    EXC_CODE_OVERFLOW: .word 12  # Arithmetic overflow

    # Status and cause register bits
    EXC_INT_ALL_MASK: .word 0x0000ff00  # Interrupt level enable bits

    EXC_INT0_MASK: .word 0x00000100  # Software
    EXC_INT1_MASK: .word 0x00000200  # Software
    EXC_INT2_MASK: .word 0x00000400  # Display
    EXC_INT3_MASK: .word 0x00000800  # Keyboard
    EXC_INT4_MASK: .word 0x00001000
    EXC_INT5_MASK: .word 0x00002000  # Timer
    EXC_INT6_MASK: .word 0x00004000
    EXC_INT7_MASK: .word 0x00008000


.text
.globl main

main:
# Initial
    jal doInitial

# Run
    jal playGame

# Exit
    j program_exit

# Procedure: doInitial
# Initialize the game
doInitial:
# BEGIN
    # Save return address
    addi $sp, $sp, -24  # Allocate stack space
    sw $ra, 0($sp)     # Save $ra on stack

# BODY
    # Print welcome message
    la $a0, welcomePrompt
    li $v0, 4
    syscall

    # Print game Welcome Page
    li $a0, 1
    jal initialDisplay 

    # Ask if the game should be started
    # 'Y' to start, 'Q' to quit
    la $a0, askPrompt
    li $v0, 4
    syscall

    li $v0, 12         # Load syscall for read char
    syscall
    
    bne $v0, 'Y', program_exit

# INTERRUPT SETTING
    # Enable interrupts in status register
    mfc0    $t0, $12

    # Disable all interrupt levels
    lw      $t1, EXC_INT_ALL_MASK
    not     $t1, $t1
    and     $t0, $t0, $t1
    
    # Enable console interrupt levels
    lw      $t1, EXC_INT3_MASK
    or      $t0, $t0, $t1
    #lw      $t1, EXC_INT4_MASK
    #or      $t0, $t0, $t1

    # Enable exceptions globally
    lw      $t1, EXC_ENABLE_MASK
    or      $t0, $t0, $t1

    mtc0    $t0, $12
    
    # Enable keyboard interrupts
    li      $t0, 0xffff0000     # Receiver control register
    li      $t1, 0x00000002     # Interrupt enable bit
    sw      $t1, ($t0)
# INTERRUPT SETTING END

    # Clear the welcome page
    li $a0, 0
    jal initialDisplay 

# RETURN
    # Restore return address
    lw $ra, 0($sp)     # Load $ra from stack
    addi $sp, $sp, 24   # Deallocate stack space

    jr $ra  # Return from procedure


# Procedure: playGame
# Run the main game program
playGame:
# BEGIN
    # Save return address
    addi $sp, $sp, -48  # Allocate stack space
    sw $ra, 0($sp)     # Save $ra on stack

# BODY
    # Print prompt message
    la $a0, playPrompt
    li $v0, 4
    syscall

    # Draw the game screen
    jal drawPlayPage

    li $t8, 0   # counter, used to limit game duration
    li $t7, 0   # counter, used to refresh blocks

    la $t0, peopleFlushTime
    lw $t0, ($t0)
    la $t1, blockFlushTime
    lw $t1, ($t1)
    div $t1, $t1, $t0   # Get multiplier
    sw $t1, 8($sp)  # Store multiplier

    game_loop:
        sw $t8, 4($sp)  # Store counter 1
        sw $t7, 12($sp) # Store counter 2

        la $t0, peopleFlushTime
        lw $a0, ($t0)
        jal program_pause

        jal drawPeople

        lw $t8, 4($sp) # Get counter 1
        lw $t7, 12($sp) # Get counter 2
        add $t7, $t7, 1
        lw $t1, 8($sp)  # Get multiplier
        beq $t7, $t1, flush_block # Refresh blocks
        j flush_block_end   # Don't refresh blocks

        flush_block:
        li $t7, 0   # Reset counter

        # Sound effect
        li $a0, 50  # low D 
        la $t0, blockFlushTime
        lw $a1, ($t0)
        sll $a1, $a1, 5 # Extend the time, otherwise it will sound unpleasant
        li $a2, 116 # Heavy drum beat
        li $a3, 100 # Volume 100
        li $v0, 31
        syscall

        # Generate random block, shift other blocks, and check scores
        # Generate random number between 0-7
        la $a0, genID
        la $a1, seed
        li $a2, 0
        li $a3, 7
        jal getRandomNum

        sw $v0, 16($sp) # Save random value
        and $v1, $v0, 0x4   # Get the highest bit (determines block generation)
        bne $v1, 0, generateNewBlock_End    # Don't generate block

        generateNewBlock:
        la $t2, fifoQueue   # Get fifo address
        la $t3, queueEnd
        lw $t3, ($t3)  # Get end
        sll $t3, $t3, 4 # t3 = t3 * 16
        add $t2, $t2, $t3 # fifo[end]

        li $t4, 480 # x
        sw $t4, ($t2)
        li $t4, 25  # size
        sw $t4, 12($t2)
        la $t3, queueEnd
        lw $t4, ($t3)  # Get end
        add $t4, $t4, 1
        sw $t4, ($t3)   # Update End

        # Generate different blocks based on the generated number
        # 00 - Blue up
        # 01 - Blue down
        # 10 - Red up
        # 11 - Red down
        lw $v0, 16($sp)
        and $v1, $v0, 0x1   # Get the low bit, corresponding to y
        bne $v1, 0, genDownBlock

        genUpBlock:
        # Sound effect
        li $a0, 72  # B#
        la $t0, blockFlushTime
        lw $a1, ($t0)
        sll $a1, $a1, 5 # Extend the time, otherwise it will sound unpleasant
        li $a2, 114 # Drumbeat sound effect
        li $a3, 100 # Volume 100
        li $v0, 31
        syscall

        la $s7, upBlockY
        lw $s7, ($s7)
        move $t4, $s7 # y
        j genColorBlock

        genDownBlock:
        # Sound effect
        li $a0, 66  # F#
        la $t0, blockFlushTime
        lw $a1, ($t0)
        sll $a1, $a1, 5 # Extend the time, otherwise it will sound unpleasant
        li $a2, 114 # Drumbeat sound effect
        li $a3, 100 # Volume 100
        li $v0, 31
        syscall

        la $s7, downBlockY
        lw $s7, ($s7)
        move $t4, $s7 # y
        j genColorBlock

        genColorBlock:
        sw $t4, 4($t2)
        lw $v0, 16($sp)
        and $v1, $v0, 0x2   # Get the high bit, corresponding to Color
        bne $v1, 0, genColorRed

        genColorBlue:
        # Sound effect
        li $a0, 69  # A
        la $t0, blockFlushTime
        lw $a1, ($t0)
        sll $a1, $a1, 5 # Extend the time, otherwise it will sound unpleasant
        li $a2, 112 # Drumbeat sound effect
        li $a3, 100 # Volume 100
        li $v0, 31
        syscall

        li $t4, 'B' # color
        j genColorFinish

        genColorRed:
        # Sound effect
        li $a0, 69  # A
        la $t0, blockFlushTime
        lw $a1, ($t0)
        sll $a1, $a1, 5 # Extend the time, otherwise it will sound unpleasant
        li $a2, 117 # Drumbeat sound effect
        li $a3, 100 # Volume 100
        li $v0, 31
        syscall

        li $t4, 'R' # color
        j genColorFinish

        genColorFinish:
        sw $t4, 8($t2)

        generateNewBlock_End:
        # Iterate through FIFO and print
        jal flushBlockFIFO

        li $a0, 0xA
        li $v0, 11
        syscall

        add $t8, $t8, 1
        la $s7, mainLoopLimit
        lw $s7, ($s7)
        beq $t8, $s7, game_loop_end

        flush_block_end:
        j game_loop

# RETURN
    game_loop_end:
    # Restore return address
    lw $ra, 0($sp)     # Load $ra from stack
    addi $sp, $sp, 48   # Deallocate stack space

    jr $ra  # Return from procedure


# Procedure: flushBlockFIFO
# Refresh output blocks based on information in the FIFO
flushBlockFIFO:
# BEGIN
    # Save return address
    addi $sp, $sp, -24  # Allocate stack space
    sw $ra, 0($sp)     # Save $ra on stack

# BODY
    la $t1, queueHead
    lw $t1, ($t1)   # Get queue head
    sll $t1, $t1, 4 # Multiply by 16 bytes
    la $t2, queueEnd
    lw $t2, ($t2)   # Get queue end
    sll $t2, $t2, 4 # Multiply by 16 bytes
    sw $t2, 8($sp)  # Save end

    flushBlockFIFO_loop:
        sw $t1, 4($sp)  # Save i
        beq $t1, $t2, flushBlockFIFO_loop_end   # Exit if output is complete

        la $t0, fifoQueue
        add $t3, $t0, $t1   # Locate fifo[i]

        sw $t3, 12($sp) # Save fifo[i]

        # Clear the original block
        lw $t3, 12($sp) 
        lw $a0, ($t3)   # x
        lw $a1, 4($t3)  # y
        li $a2, '0'
        lw $a3, 12($t3) # size
        jal drawBox

        # Draw the new block (x reduced)
        lw $t3, 12($sp) 
        lw $a0, ($t3)   # x
        lw $a1, 4($t3)  # y
        lw $a2, 8($t3)  # color
        lw $a3, 12($t3) # size

        la $s7, blockSpeed
        lw $s7, ($s7)
        sub $a0, $a0, $s7    # Reduce x
        sw $a0, ($t3)   # Save x

        jal drawBox

        # Check if x has reached the position of the person
        lw $t3, 12($sp) 
        lw $a0, ($t3)   # x
        la $s7, triggerPosition
        lw $s7, ($s7)
        ble $a0, $s7, deal_with_reach_block
        j flushBlockFIFO_loop_continue

        # Handle blocks that have reached the person's position
        deal_with_reach_block:
        # Remove the current block from the FIFO
        la $t1, queueHead
        lw $a1, ($t1)   # Get queue head
        add $a1, $a1, 1
        sw $a1, ($t1)   # Update queue head

        la $s7, blockDisappearDelay
        lw $s7, ($s7)
        move $a0, $s7 # Pause for 500ms
        jal program_pause

        # Clear the current block
        lw $t3, 12($sp) 
        lw $a0, ($t3)   # x
        lw $a1, 4($t3)  # y
        li $a2, '0'
        lw $a3, 12($t3) # size
        jal drawBox

        # Check for death or scoring
        lw $t3, 12($sp) 
        lw $a1, 4($t3)  # y
        lw $a2, 8($t3)  # color

        la $s7, downBlockY
        lw $s7, ($s7)
        beq $a1, $s7, now_block_is_down # If the current block is down

        now_block_is_up:
        # If the person's state is not up
        la $s7, peopleState
        lw $s7, ($s7)
        beq $s7, 'D', deal_with_reach_block_end

        # If the person's state is also up
        beq $a2, 'B', now_block_is_blue
        j now_block_is_red

        now_block_is_down:
        # If the person's state is not down
        la $s7, peopleState
        lw $s7, ($s7)
        beq $s7, 'U', deal_with_reach_block_end

        # If the person's state is also down
        beq $a2, 'B', now_block_is_blue
        j now_block_is_red

        now_block_is_red:
        li $a0, 49  # Low 8 degree C # tuning
        li $a1, 800
        li $a2, 32 # Bass effect
        li $a3, 120 # Volume 120
        li $v0, 33  # synchronization
        syscall

        jal drawPeople # Correct the person's state

        # LOSE
        jal gameLose

        j flushBlockFIFO_loop_continue

        now_block_is_blue:
        li $a0, 69  # A
        li $a1, 800
        li $a2, 8 # Half-tone percussion
        li $a3, 120 # Volume 120
        li $v0, 31  # synchronization
        syscall

        # Get the score
        la $s7, scoreChar
        lw $s6, ($s7)
        add $s6, $s6, 1
        sw $s6, ($s7)   # Update the score

        # Update the game score
        li $a0, 8
        li $a1, 8
        la $a2, '0'
        la $a3, 20
        jal drawBox

        li $a0, 8
        li $a1, 8
        la $a2, scoreChar
        jal OutText

        la $s7, scoreChar
        lw $s6, ($s7)
        la $s7, winScoreChar
        lw $s7, ($s7)   # Winning score
        bge $s6, $s7, scoreIsEnough   # If the score is enough, Win
        j flushBlockFIFO_loop_continue

        scoreIsEnough:
        jal drawPeople  # Correct the person's state

        jal gameWin
        j flushBlockFIFO_loop_continue

        deal_with_reach_block_end:
        j flushBlockFIFO_loop_continue

        flushBlockFIFO_loop_continue:
        lw $t1, 4($sp)  # Get i
        lw $t2, 8($sp)  # Get end
        add $t1, $t1, 16    # Move forward by 4 * 4 bytes
        
        j flushBlockFIFO_loop

# RETURN
    flushBlockFIFO_loop_end:
    # Restore return address
    lw $ra, 0($sp)     # Load $ra from stack
    addi $sp, $sp, 24   # Deallocate stack space

    jr $ra  # Return from procedure


# Procedure: initialDisplay
# Display the welcome page or clear it
# $a0 - 0 for clear
initialDisplay:
# BEGIN
    # Save return address
    addi $sp, $sp, -24  # Allocate stack space
    sw $ra, 0($sp)     # Save $ra on stack
    sw $a0, 8($sp)

# BODY
    li $t0, 0 # as counter
    sw $t0, 4($sp)  # store counter

    welcomePage_loop:
    lw $t0, 4($sp)  # get counter
    la $t1, welcomeTableCount  # get welcomeTableCount number
    lw $t1, 0($t1)
    beq $t0, $t1,   welcomePage_loop_end   # if draw finish

    la $t1, welcomeTable # get table address
    sll $t2, $t0, 4 # t2 = counter * 16
    add $t1, $t1, $t2 # t1 = address of welcomeTable[counter]

    add $t0, $t0, 1 # counter++
    sw $t0, 4($sp)  # store counter

    lw $a2, 8($t1)  # get Color
    lw $a0, 8($sp) # Check if clear
    bne $a0, 0, not_clear

    clear:
    li $a2, '0'

    not_clear:
    lw $a0, 0($t1)  # get x
    lw $a1, 4($t1)  # get y
    lw $a3, 12($t1) # get size 
    jal drawBox

    j   welcomePage_loop

# RETURN
    welcomePage_loop_end:
    # Restore return address
    lw $ra, 0($sp)     # Load $ra from stack
    addi $sp, $sp, 24   # Deallocate stack space

    jr $ra  # Return from procedure


# Procedure: drawPlayPage
# Draw the game screen
drawPlayPage:
# BEGIN
    # Save return address
    addi $sp, $sp, -24  # Allocate stack space
    sw $ra, 0($sp)     # Save $ra on stack

# BODY
    # Draw horizontal white line in the middle
    li $a0, 0 # x
    li $a1, 127 # y
    li $a2, 'W' # White
    li $a3, 512 # size
    jal drawHorzLine

    li $a0, 0 # x
    li $a1, 128 # y
    li $a2, 'W' # White
    li $a3, 512 # size
    jal drawHorzLine

    li $a0, 0 # x
    li $a1, 129 # y
    li $a2, 'W' # White
    li $a3, 512 # size
    jal drawHorzLine

    # Draw score box in the top-left corner
    li $a0, 32 # x
    li $a1, 0 # y
    li $a2, 'W' # White
    li $a3, 32 # size
    jal drawVertLine

    li $a0, 0 # x
    li $a1, 32 # y
    li $a2, 'W' # White
    li $a3, 32 # size
    jal drawHorzLine

    li $a0, 8
    li $a1, 8
    la $a2, scoreChar
    jal OutText

    # Draw the person (initially facing up)
    jal drawPeople

# RETURN
    # Restore return address
    lw $ra, 0($sp)     # Load $ra from stack
    addi $sp, $sp, 24   # Deallocate stack space

    jr $ra  # Return from procedure


# Procedure: drawPeople
# Draw the character
drawPeople:
# BEGIN
    # Save return address
    addi $sp, $sp, -24  # Allocate stack space
    sw $ra, 0($sp)     # Save $ra on stack

# BODY
    # Get the character's state
    la $t0, peopleState
    lw $a0, ($t0)

    beq $a0, 'U', draw_up
    beq $a0, 'D', draw_down
    j draw_end

    draw_up:
    # Clear down
    li $a0, 60 # x
    li $a1, 188 # y
    li $a2, '0'
    jal drawRound

    li $a0, 0
    li $a1, 'D'
    jal drawBody

    # Draw head
    li $a0, 60 # x
    li $a1, 42 # y
    li $a2, 'G'
    jal drawRound

    li $a0, 1
    li $a1, 'U'
    jal drawBody

    j draw_end

    draw_down:
    # Clear up
    li $a0, 60 # x
    li $a1, 42 # y
    li $a2, '0'
    jal drawRound

    li $a0, 0
    li $a1, 'U'
    jal drawBody

    # Draw head
    li $a0, 60 # x
    li $a1, 188 # y
    li $a2, 'G'
    jal drawRound

    li $a0, 1
    li $a1, 'D'
    jal drawBody

    j draw_end

# RETURN
    draw_end:
    # Restore return address
    lw $ra, 0($sp)     # Load $ra from stack
    addi $sp, $sp, 24   # Deallocate stack space

    jr $ra  # Return from procedure


# Procedure: drawBody
# Draw the character's body
# $a0 - 0 for clear
# $a1 - 'U' for up (default), 'D' for down
drawBody:
# BEGIN
    # Save return address
    addi $sp, $sp, -24  # Allocate stack space
    sw $ra, 0($sp)     # Save $ra on stack
    sw $a0, 8($sp)
    sw $a1, 12($sp)

# BODY
    li $t0, 0 # Counter
    sw $t0, 4($sp)  # Store counter

    drawBody_loop:
    lw $t0, 4($sp)  # Get counter
    la $t1, peopleTableCount  # Get peopleTableCount
    lw $t1, 0($t1)
    beq $t0, $t1, drawBody_loop_end   # Exit if drawing is complete

    la $t1, peopleTable # Get table address
    sll $t2, $t0, 4 # t2 = counter * 16
    add $t1, $t1, $t2 # t1 = address of peopleTable[counter]

    add $t0, $t0, 1 # Increment counter
    sw $t0, 4($sp)  # Store counter

    lw $a2, 8($t1)  # Get color
    lw $a0, 8($sp) # Check if clear
    bne $a0, 0, body_not_clear

    body_clear:
    li $a2, '0'

    body_not_clear:
    lw $a1, 12($sp)
    beq $a1, 'D', body_down
    j body_not_down

    body_down:
    lw $a1, 4($t1)  # Get y
    li $a3, 255 
    sub $a1, $a3, $a1
    j body_others

    body_not_down:
    lw $a1, 4($t1)  # Get y
    j body_others

    body_others:
    lw $a0, 0($t1)  # Get x
    lw $a3, 12($t1) # Get size 
    jal drawBox

    j drawBody_loop

# RETURN
    drawBody_loop_end:
    # Restore return address
    lw $ra, 0($sp)     # Load $ra from stack
    addi $sp, $sp, 24   # Deallocate stack space

    jr $ra  # Return from procedure


# Procedure: getRandomNum
# Get random number for a sequence, [a, b]
# $a0 = pointer to genID
# $a1 = pointer to seed
# $a2 = lower limit: a
# $a3 = upper limit: b
# $v0 = generated random number
getRandomNum:
# BEGIN
    # Save return address
    addi $sp, $sp, -24  # Allocate stack space
    sw $ra, 0($sp)     # Save $ra on stack
    sw $a2, 4($sp)      # a
    sw $a3, 8($sp)      # b

# BODY
    # Clear
    sw $0, 0($a0)      # Set generator ID to 0

    # Save addresses
    move $t0, $a0      # Copy address of genID from $a0 to $t0
    move $t1, $a1      # Copy address of seed from $a1 to $t1

    # Get and store system time
    li $v0, 30
    syscall
    sw $a0, 0($t1)     # Store system time into seed

    # Set and store seed
    lw $a0, ($t0)      # Set $a0 to genID
    lw $a1, ($t1)      # Set $a1 to seed
    li $v0, 40         # Load syscall for seed
    syscall
    sw $a1, 0($t1)     # Store generated seed into the seed label

    # Pause for randomness
    li $a0, 10         # Sleep for 10ms
    jal program_pause

    # Generate random number in range 1-4
    lw $a2, 4($sp)      # a
    lw $a3, 8($sp)      # b
    sub $a1, $a3, $a2
    add $a1, $a1, 1    # Upper bound of range = b - a + 1
    li $v0, 42         # Load syscall for random int range
    syscall
    add $a0, $a0, $a2   # Add a to make the range [a, b]
    move $v0, $a0      # Copy generated random number to $v0

    # Reset addresses
    move $a0, $t0      # Copy address of genID from $t0 to $a0
    move $a1, $t1      # Copy address of seed from $t1 to $a1

# RETURN
    # Restore return address
    lw $ra, 0($sp)     # Load $ra from stack
    addi $sp, $sp, 24   # Deallocate stack space

    jr $ra             # Return from procedure


# Procedure: gameWin
# Game win
# $a0 = Starting address of the array for storage
# $a1 = Number of floats to be entered
gameWin:
# BEGIN
    # Save return address
    addi $sp, $sp, -24  # Allocate stack space
    sw $ra, 0($sp)     # Save $ra on stack

# BODY
    # Sound effect
    li $a0, 72  # Low D 
    li $a1, 3000
    li $a2, 126 # Applause
    li $a3, 100 # Volume 100
    li $v0, 31
    syscall
    
    # Sound effect
    li $a0, 72  # Low D 
    li $a1, 3000
    li $a2, 122 # Applause
    li $a3, 100 # Volume 100
    li $v0, 31
    syscall

    la $a0, winPrompt
    li $v0, 4
    syscall

    jal winFun

    jal program_exit

# RETURN
    # Restore return address
    lw $ra, 0($sp)     # Load $ra from stack
    addi $sp, $sp, 24   # Deallocate stack space

    jr $ra  # Return from procedure


# Procedure: winFun:
# Fun for the winner!
winFun:
# BEGIN
    # Make room on stack
    addi $sp, $sp, -12   # Make room on stack for 3 words
    sw $ra, 0($sp)      # Store $ra on stack

# BODY
    # li $a0, 0
    # li $a1, 0
    # li $a2, 0
    # li $a3, 255
    # jal drawBox

    li $t0, 0 # Counter
    sw $t0, 4($sp)  # Store counter

    winFun_loop:
    lw $t0, 4($sp)  # Get counter
    la $t1, winFunTableCount  # Get tableCount
    lw $t1, 0($t1)
    beq $t0, $t1, winFun_loop_end   # Exit if drawing is complete

    la $t1, winFunTable # Get table address
    sll $t2, $t0, 4 # t2 = counter * 16
    add $t1, $t1, $t2 # t1 = address of winFunTable[counter]

    add $t0, $t0, 1 # Increment counter
    sw $t0, 4($sp)  # Store counter

    lw $a0, 0($t1)  # Get x
    lw $a1, 4($t1)  # Get y
    lw $a2, 8($t1)  # Get color
    lw $a3, 12($t1) # Get size 
    jal drawBox

    j winFun_loop

# RETURN
    winFun_loop_end:
    # Restore $RA
    lw $ra, 0($sp)   # Restore $ra from stack
    addi $sp, $sp, 12   # Readjust stack

    jr $ra   # Return  


# Procedure: gameLose
# Game over
# $a0 = Starting address of the array for storage
# $a1 = Number of floats to be entered
gameLose:
# BEGIN
    # Save return address
    addi $sp, $sp, -24  # Allocate stack space
    sw $ra, 0($sp)     # Save $ra on stack

# BODY
    # Sound effect
    li $a0, 45  # low low A
    li $a1, 3000
    li $a2, 96 # Fail
    li $a3, 100 # Volume 100
    li $v0, 31
    syscall

    la $a0, losePrompt
    li $v0, 4
    syscall

    jal loseTerrible

    jal program_exit

# RETURN
    # Restore return address
    lw $ra, 0($sp)     # Load $ra from stack
    addi $sp, $sp, 24   # Deallocate stack space

    jr $ra  # Return from procedure


# Procedure: loseTerrible:
# Oops, loser!
loseTerrible:
# BEGIN
    # Make room on stack
    addi $sp, $sp, -12   # Make room on stack for 3 words
    sw $ra, 0($sp)      # Store $ra on element 4 of stack

# BODY
    # li $a0, 0
    # li $a1, 0
    # li $a2, 0
    # li $a3, 255
    # jal drawBox

    li $t0, 0 # Counter
    sw $t0, 4($sp)  # Store counter

    loseTerrible_loop:
    lw $t0, 4($sp)  # Get counter
    la $t1, loseTerribleTableCount  # Get tableCount
    lw $t1, 0($t1)
    beq $t0, $t1, loseTerrible_loop_end   # Exit if drawing is complete

    la $t1, loseTerribleTable # Get table address
    sll $t2, $t0, 4 # t2 = counter * 16
    add $t1, $t1, $t2 # t1 = address of loseTerribleTable[counter]

    add $t0, $t0, 1 # Increment counter
    sw $t0, 4($sp)  # Store counter

    lw $a0, 0($t1)  # Get x
    lw $a1, 4($t1)  # Get y
    lw $a2, 8($t1)  # Get Color
    lw $a3, 12($t1) # Get size 
    jal drawBox

    j loseTerrible_loop

# RETURN
    loseTerrible_loop_end:
    # RESTORE $RA
    lw $ra, 0($sp)   # Restore $ra from stack
    addi $sp, $sp, 12   # Readjust stack

    jr $ra   # Return  


# Procedure: program_pause:
# Pause the program execution for a specified time
# $a1 for sleep time (ms)
program_pause:
# BEGIN
    # Save return address
    addi $sp, $sp, -4   # Allocate stack space
    sw $ra, 0($sp)   # Save $ra on stack

# BODY
    li $v0, 32   # Load syscall for sleep
    syscall

# RETURN
    # Restore return address
    lw $ra, 0($sp)   # Load $ra from stack
    addi $sp, $sp, 4   # Deallocate stack space

    jr $ra   # Return from procedure


# Procedure: program_exit
# Exit the program
program_exit:
    # Output exit message
    la $a0, exitPrompt
    li $v0, 4
    syscall

    li $v0, 17   # Load exit call
    syscall


.data
    diameter:   .word 30
    roundTable: # The parameters of the short chords of a circle
 .byte 5,  7,  9,  10,  11,  12,  12,  13,  13,  14
 .byte 14,  14,  14,  14,  15,  15,  14,  14,  14,  14
 .byte 14,  13,  13,  12,  12,  11,  10,  9,  7,  5


.data
    welcomeTable: # Table for draw welcome page
    # x, y, color, size
        .word 30, 5, 'W', 5,   29, 7, 'W', 5,   28, 10, 'W', 5,   27, 13, 'W', 5,   26, 16, 'W', 5,   25, 19, 'W', 5,   25, 22, 'W', 5,   24, 25, 'W', 5,   23, 28, 'W', 5,   22, 30, 'W', 5,   21, 33, 'W', 5,   20, 36, 'W', 5,   20, 39, 'W', 5,   19, 42, 'W', 5,   18, 45, 'W', 5,   17, 48, 'W', 5,   16, 51, 'W', 5,   16, 54, 'W', 5,   15, 56, 'W', 5,   14, 59, 'W', 5,   13, 62, 'W', 5,   12, 65, 'W', 5,   11, 68, 'W', 5,   30, 5, 'W', 5,   32, 6, 'W', 5,   34, 8, 'W', 5,   37, 10, 'W', 5,   39, 12, 'W', 5,   41, 14, 'W', 5,   44, 16, 'W', 5,   46, 17, 'W', 5,   48, 19, 'W', 5,   51, 21, 'W', 5,   53, 23, 'W', 5,   55, 25, 'W', 5,   11, 72, 'W', 5,   13, 71, 'W', 5,   16, 70, 'W', 5,   19, 69, 'W', 5,   22, 68, 'W', 5,   25, 68, 'W', 5,   28, 67, 'W', 5,   31, 66, 'W', 5,   34, 65, 'W', 5,   37, 65, 'W', 5,   40, 64, 'W', 5,   42, 63, 'W', 5,   58, 27, 'W', 5,   56, 29, 'W', 5,   55, 32, 'W', 5
        .word 54, 35, 'W', 5,   53, 38, 'W', 5,   52, 41, 'W', 5,   51, 43, 'W', 5,   50, 46, 'W', 5,   49, 49, 'W', 5,   48, 52, 'W', 5,   47, 55, 'W', 5,   46, 58, 'W', 5,   45, 60, 'W', 5,   68, 27, 'W', 5,   70, 27, 'W', 5,   73, 27, 'W', 5,   76, 27, 'W', 5,   79, 27, 'W', 5,   82, 27, 'W', 5,   85, 27, 'W', 5,   88, 27, 'W', 5,   91, 27, 'W', 5,   94, 27, 'W', 5,   68, 27, 'W', 5,   67, 29, 'W', 5,   66, 32, 'W', 5,   65, 35, 'W', 5,   65, 38, 'W', 5,   64, 41, 'W', 5,   63, 44, 'W', 5,   62, 47, 'W', 5,   62, 50, 'W', 5,   61, 53, 'W', 5,   60, 56, 'W', 5,   59, 58, 'W', 5,   59, 62, 'W', 5,   61, 61, 'W', 5,   64, 61, 'W', 5,   67, 61, 'W', 5,   70, 61, 'W', 5,   73, 61, 'W', 5,   76, 61, 'W', 5,   79, 61, 'W', 5,   82, 61, 'W', 5,   85, 61, 'W', 5,   99, 28, 'W', 5,   98, 30, 'W', 5,   97, 33, 'W', 5,   96, 36, 'W', 5,   95, 39, 'W', 5,   94, 42, 'W', 5,   93, 45, 'W', 5,   92, 47, 'W', 5
        .word 91, 50, 'W', 5,   90, 53, 'W', 5,   89, 56, 'W', 5,   88, 59, 'W', 5,   121, 29, 'W', 5,   119, 31, 'W', 5,   118, 34, 'W', 5,   117, 37, 'W', 5,   116, 40, 'W', 5,   115, 43, 'W', 5,   114, 45, 'W', 5,   113, 48, 'W', 5,   112, 51, 'W', 5,   111, 54, 'W', 5,   110, 57, 'W', 5,   121, 29, 'W', 5,   122, 31, 'W', 5,   123, 34, 'W', 5,   125, 36, 'W', 5,   126, 39, 'W', 5,   128, 42, 'W', 5,   129, 44, 'W', 5,   130, 47, 'W', 5,   132, 50, 'W', 5,   133, 52, 'W', 5,   135, 55, 'W', 5,   136, 58, 'W', 5,   138, 61, 'W', 5,   138, 58, 'W', 5,   139, 55, 'W', 5,   140, 52, 'W', 5,   140, 49, 'W', 5,   141, 46, 'W', 5,   142, 43, 'W', 5,   143, 40, 'W', 5,   143, 37, 'W', 5,   144, 34, 'W', 5,   145, 31, 'W', 5,   167, 7, 'W', 5,   166, 9, 'W', 5,   165, 12, 'W', 5,   164, 15, 'W', 5,   163, 18, 'W', 5,   162, 21, 'W', 5,   161, 24, 'W', 5,   160, 27, 'W', 5,   181, 28, 'W', 5,   183, 28, 'W', 5,   186, 28, 'W', 5,   189, 28, 'W', 5
        .word 192, 28, 'W', 5,   195, 28, 'W', 5,   198, 28, 'W', 5,   201, 28, 'W', 5,   204, 28, 'W', 5,   207, 28, 'W', 5,   210, 28, 'W', 5,   213, 28, 'W', 5,   216, 28, 'W', 5,   200, 28, 'W', 5,   199, 30, 'W', 5,   198, 33, 'W', 5,   197, 36, 'W', 5,   196, 39, 'W', 5,   195, 42, 'W', 5,   194, 45, 'W', 5,   193, 47, 'W', 5,   192, 50, 'W', 5,   191, 53, 'W', 5,   190, 56, 'W', 5,   189, 59, 'W', 5,   188, 62, 'W', 5,   187, 64, 'W', 5,   186, 67, 'W', 5,   282, 5, 'W', 5,   285, 5, 'W', 5,   288, 5, 'W', 5,   291, 5, 'W', 5,   294, 5, 'W', 5,   297, 5, 'W', 5,   300, 5, 'W', 5,   303, 5, 'W', 5,   306, 5, 'W', 5,   309, 5, 'W', 5,   312, 5, 'W', 5,   315, 5, 'W', 5,   318, 5, 'W', 5,   321, 5, 'W', 5,   324, 5, 'W', 5,   327, 5, 'W', 5,   330, 5, 'W', 5,   333, 5, 'W', 5,   336, 5, 'W', 5,   339, 5, 'W', 5,   342, 5, 'W', 5,   345, 5, 'W', 5,   348, 5, 'W', 5,   318, 5, 'W', 5,   317, 7, 'W', 5,   316, 10, 'W', 5
        .word 315, 13, 'W', 5,   315, 16, 'W', 5,   314, 19, 'W', 5,   313, 22, 'W', 5,   313, 25, 'W', 5,   312, 28, 'W', 5,   311, 31, 'W', 5,   311, 34, 'W', 5,   310, 37, 'W', 5,   309, 40, 'W', 5,   309, 42, 'W', 5,   308, 45, 'W', 5,   307, 48, 'W', 5,   307, 51, 'W', 5,   306, 54, 'W', 5,   305, 57, 'W', 5,   304, 60, 'W', 5,   304, 63, 'W', 5,   303, 66, 'W', 5,   302, 69, 'W', 5,   337, 36, 'W', 5,   340, 36, 'W', 5,   343, 36, 'W', 5,   346, 36, 'W', 5,   349, 36, 'W', 5,   352, 36, 'W', 5,   355, 36, 'W', 5,   358, 36, 'W', 5,   361, 36, 'W', 5,   364, 36, 'W', 5,   337, 36, 'W', 5,   336, 38, 'W', 5,   335, 41, 'W', 5,   334, 44, 'W', 5,   334, 47, 'W', 5,   333, 50, 'W', 5,   332, 53, 'W', 5,   332, 56, 'W', 5,   331, 59, 'W', 5,   330, 62, 'W', 5,   330, 65, 'W', 5,   329, 68, 'W', 5,   368, 36, 'W', 5,   366, 38, 'W', 5,   365, 41, 'W', 5,   364, 44, 'W', 5,   363, 47, 'W', 5,   362, 49, 'W', 5,   360, 52, 'W', 5,   359, 55, 'W', 5
        .word 329, 70, 'W', 5,   331, 68, 'W', 5,   334, 67, 'W', 5,   337, 66, 'W', 5,   340, 65, 'W', 5,   343, 64, 'W', 5,   345, 63, 'W', 5,   348, 62, 'W', 5,   351, 61, 'W', 5,   354, 60, 'W', 5,   391, 36, 'W', 5,   389, 38, 'W', 5,   388, 41, 'W', 5,   387, 44, 'W', 5,   386, 46, 'W', 5,   384, 49, 'W', 5,   383, 52, 'W', 5,   382, 55, 'W', 5,   381, 57, 'W', 5,   380, 60, 'W', 5,   378, 63, 'W', 5,   377, 66, 'W', 5,   377, 68, 'W', 5,   379, 67, 'W', 5,   382, 67, 'W', 5,   385, 67, 'W', 5,   388, 67, 'W', 5,   391, 67, 'W', 5,   394, 67, 'W', 5,   397, 67, 'W', 5,   400, 67, 'W', 5,   405, 67, 'W', 5,   406, 64, 'W', 5,   407, 61, 'W', 5,   408, 58, 'W', 5,   409, 55, 'W', 5,   410, 53, 'W', 5,   411, 50, 'W', 5,   413, 47, 'W', 5,   414, 44, 'W', 5,   415, 42, 'W', 5,   416, 39, 'W', 5,   438, 35, 'W', 5,   440, 34, 'W', 5,   443, 34, 'W', 5,   446, 34, 'W', 5,   449, 34, 'W', 5,   452, 34, 'W', 5,   455, 34, 'W', 5,   438, 35, 'W', 5
        .word 436, 37, 'W', 5,   435, 40, 'W', 5,   434, 43, 'W', 5,   433, 45, 'W', 5,   431, 48, 'W', 5,   430, 51, 'W', 5,   429, 54, 'W', 5,   428, 56, 'W', 5,   427, 59, 'W', 5,   425, 62, 'W', 5,   424, 65, 'W', 5,   424, 67, 'W', 5,   427, 67, 'W', 5,   430, 67, 'W', 5,   433, 67, 'W', 5,   436, 67, 'W', 5,   439, 67, 'W', 5,   442, 67, 'W', 5,   445, 67, 'W', 5,   448, 67, 'W', 5,   480, 5, 'W', 5,   479, 7, 'W', 5,   478, 10, 'W', 5,   477, 13, 'W', 5,   477, 16, 'W', 5,   476, 19, 'W', 5,   475, 22, 'W', 5,   474, 25, 'W', 5,   474, 28, 'W', 5,   473, 31, 'W', 5,   472, 34, 'W', 5,   471, 36, 'W', 5,   471, 39, 'W', 5,   470, 42, 'W', 5,   469, 45, 'W', 5,   468, 48, 'W', 5,   468, 51, 'W', 5,   467, 54, 'W', 5,   466, 57, 'W', 5,   465, 60, 'W', 5,   465, 63, 'W', 5,   464, 66, 'W', 5,   463, 68, 'W', 5,   463, 71, 'W', 5,   500, 5, 'W', 5,   499, 7, 'W', 5,   498, 10, 'W', 5,   497, 13, 'W', 5,   497, 16, 'W', 5,   496, 19, 'W', 5
        .word 495, 22, 'W', 5,   495, 25, 'W', 5,   494, 28, 'W', 5,   493, 31, 'W', 5,   493, 34, 'W', 5,   492, 37, 'W', 5,   491, 40, 'W', 5,   491, 43, 'W', 5,   490, 45, 'W', 5,   489, 48, 'W', 5,   489, 51, 'W', 5,   488, 54, 'W', 5,   487, 57, 'W', 5,   487, 60, 'W', 5,   486, 63, 'W', 5,   485, 66, 'W', 5,   485, 69, 'W', 5,   484, 72, 'W', 5,   472, 38, 'W', 5,   474, 37, 'W', 5,   477, 37, 'W', 5,   480, 37, 'W', 5,   483, 37, 'W', 5,   486, 37, 'W', 5,   489, 37, 'W', 5,   290, 104, 'W', 5,   292, 105, 'W', 5,   294, 107, 'W', 5,   296, 109, 'W', 5,   299, 111, 'W', 5,   301, 113, 'W', 5,   303, 115, 'W', 5,   306, 117, 'W', 5,   308, 119, 'W', 5,   310, 121, 'W', 5,   313, 123, 'W', 5,   315, 125, 'W', 5,   317, 126, 'W', 5,   290, 104, 'W', 5,   289, 106, 'W', 5,   289, 109, 'W', 5,   289, 112, 'W', 5,   288, 115, 'W', 5,   288, 118, 'W', 5,   288, 121, 'W', 5,   287, 124, 'W', 5,   287, 127, 'W', 5,   287, 130, 'W', 5,   286, 133, 'W', 5,   286, 136, 'W', 5
        .word 286, 139, 'W', 5,   285, 142, 'W', 5,   285, 145, 'W', 5,   285, 148, 'W', 5,   284, 151, 'W', 5,   284, 154, 'W', 5,   284, 157, 'W', 5,   283, 160, 'W', 5,   283, 163, 'W', 5,   283, 166, 'W', 5,   282, 169, 'W', 5,   282, 172, 'W', 5,   282, 175, 'W', 5,   282, 178, 'W', 5,   281, 181, 'W', 5,   281, 184, 'W', 5,   281, 187, 'W', 5,   280, 190, 'W', 5,   280, 193, 'W', 5,   280, 196, 'W', 5,   279, 199, 'W', 5,   279, 202, 'W', 5,   279, 205, 'W', 5,   278, 208, 'W', 5,   278, 211, 'W', 5,   278, 214, 'W', 5,   277, 217, 'W', 5,   277, 220, 'W', 5,   277, 223, 'W', 5,   276, 226, 'W', 5,   276, 229, 'W', 5,   276, 232, 'W', 5,   319, 128, 'W', 5,   316, 130, 'W', 5,   314, 132, 'W', 5,   312, 134, 'W', 5,   310, 136, 'W', 5,   307, 138, 'W', 5,   305, 140, 'W', 5,   303, 142, 'W', 5,   301, 144, 'W', 5,   299, 146, 'W', 5,   296, 148, 'W', 5,   294, 150, 'W', 5,   292, 152, 'W', 5,   290, 154, 'W', 5,   288, 156, 'W', 5,   285, 158, 'W', 5,   284, 160, 'W', 5,   286, 162, 'W', 5
        .word 288, 164, 'W', 5,   290, 166, 'W', 5,   292, 168, 'W', 5,   294, 170, 'W', 5,   296, 172, 'W', 5,   298, 175, 'W', 5,   300, 177, 'W', 5,   302, 179, 'W', 5,   304, 181, 'W', 5,   307, 183, 'W', 5,   309, 185, 'W', 5,   311, 187, 'W', 5,   313, 190, 'W', 5,   315, 192, 'W', 5,   317, 194, 'W', 5,   319, 196, 'W', 5,   321, 198, 'W', 5,   324, 201, 'W', 5,   321, 202, 'W', 5,   319, 204, 'W', 5,   316, 206, 'W', 5,   314, 207, 'W', 5,   311, 209, 'W', 5,   309, 211, 'W', 5,   306, 213, 'W', 5,   304, 214, 'W', 5,   301, 216, 'W', 5,   299, 218, 'W', 5,   297, 220, 'W', 5,   294, 221, 'W', 5,   292, 223, 'W', 5,   289, 225, 'W', 5,   287, 227, 'W', 5,   284, 228, 'W', 5,   282, 230, 'W', 5,   279, 232, 'W', 5,   277, 233, 'W', 5,   357, 105, 'W', 5,   356, 107, 'W', 5,   356, 110, 'W', 5,   355, 113, 'W', 5,   355, 116, 'W', 5,   354, 119, 'W', 5,   354, 122, 'W', 5,   353, 125, 'W', 5,   353, 128, 'W', 5,   352, 131, 'W', 5,   352, 134, 'W', 5,   351, 137, 'W', 5,   351, 140, 'W', 5
        .word 350, 143, 'W', 5,   350, 146, 'W', 5,   349, 149, 'W', 5,   349, 152, 'W', 5,   348, 155, 'W', 5,   348, 158, 'W', 5,   347, 161, 'W', 5,   347, 164, 'W', 5,   346, 167, 'W', 5,   346, 170, 'W', 5,   345, 173, 'W', 5,   345, 176, 'W', 5,   344, 179, 'W', 5,   344, 181, 'W', 5,   343, 184, 'W', 5,   343, 187, 'W', 5,   342, 190, 'W', 5,   342, 193, 'W', 5,   341, 196, 'W', 5,   341, 199, 'W', 5,   340, 202, 'W', 5,   340, 205, 'W', 5,   340, 208, 'W', 5,   339, 211, 'W', 5,   339, 214, 'W', 5,   338, 217, 'W', 5,   338, 220, 'W', 5,   337, 223, 'W', 5,   337, 226, 'W', 5,   336, 229, 'W', 5,   336, 233, 'W', 5,   338, 232, 'W', 5,   341, 232, 'W', 5,   344, 232, 'W', 5,   347, 232, 'W', 5,   350, 232, 'W', 5,   353, 232, 'W', 5,   356, 232, 'W', 5,   359, 232, 'W', 5,   362, 232, 'W', 5,   365, 232, 'W', 5,   368, 232, 'W', 5,   371, 232, 'W', 5,   374, 232, 'W', 5,   380, 155, 'W', 5,   383, 155, 'W', 5,   386, 155, 'W', 5,   389, 155, 'W', 5,   392, 155, 'W', 5,   395, 155, 'W', 5
        .word 398, 155, 'W', 5,   401, 155, 'W', 5,   404, 155, 'W', 5,   407, 155, 'W', 5,   410, 155, 'W', 5,   380, 155, 'W', 5,   379, 157, 'W', 5,   378, 160, 'W', 5,   377, 163, 'W', 5,   377, 166, 'W', 5,   376, 169, 'W', 5,   375, 172, 'W', 5,   375, 175, 'W', 5,   374, 178, 'W', 5,   373, 181, 'W', 5,   373, 184, 'W', 5,   372, 187, 'W', 5,   371, 190, 'W', 5,   371, 192, 'W', 5,   370, 195, 'W', 5,   369, 198, 'W', 5,   369, 201, 'W', 5,   368, 206, 'W', 5,   370, 205, 'W', 5,   373, 205, 'W', 5,   376, 205, 'W', 5,   379, 205, 'W', 5,   382, 205, 'W', 5,   385, 205, 'W', 5,   388, 205, 'W', 5,   391, 205, 'W', 5,   394, 205, 'W', 5,   397, 205, 'W', 5,   413, 155, 'W', 5,   412, 157, 'W', 5,   411, 160, 'W', 5,   410, 163, 'W', 5,   409, 166, 'W', 5,   409, 169, 'W', 5,   408, 172, 'W', 5,   407, 175, 'W', 5,   406, 178, 'W', 5,   406, 181, 'W', 5,   405, 184, 'W', 5,   404, 186, 'W', 5,   403, 189, 'W', 5,   403, 192, 'W', 5,   402, 195, 'W', 5,   401, 198, 'W', 5,   400, 201, 'W', 5
        .word 430, 156, 'W', 5,   432, 155, 'W', 5,   435, 155, 'W', 5,   438, 155, 'W', 5,   441, 155, 'W', 5,   444, 155, 'W', 5,   447, 155, 'W', 5,   418, 204, 'W', 5,   420, 203, 'W', 5,   423, 203, 'W', 5,   426, 203, 'W', 5,   429, 203, 'W', 5,   432, 203, 'W', 5,   435, 203, 'W', 5,   430, 156, 'W', 5,   429, 158, 'W', 5,   428, 161, 'W', 5,   427, 164, 'W', 5,   427, 167, 'W', 5,   426, 170, 'W', 5,   425, 173, 'W', 5,   424, 176, 'W', 5,   424, 179, 'W', 5,   423, 182, 'W', 5,   422, 185, 'W', 5,   421, 188, 'W', 5,   421, 190, 'W', 5,   420, 193, 'W', 5,   419, 196, 'W', 5,   419, 199, 'W', 5,   474, 106, 'W', 5,   473, 108, 'W', 5,   473, 111, 'W', 5,   472, 114, 'W', 5,   472, 117, 'W', 5,   471, 120, 'W', 5,   471, 123, 'W', 5,   470, 126, 'W', 5,   470, 129, 'W', 5,   469, 132, 'W', 5,   469, 135, 'W', 5,   468, 138, 'W', 5,   468, 141, 'W', 5,   468, 144, 'W', 5,   467, 147, 'W', 5,   467, 150, 'W', 5,   466, 153, 'W', 5,   466, 156, 'W', 5,   465, 159, 'W', 5,   465, 162, 'W', 5
        .word 464, 165, 'W', 5,   464, 168, 'W', 5,   463, 171, 'W', 5,   463, 174, 'W', 5,   462, 177, 'W', 5,   462, 180, 'W', 5,   462, 183, 'W', 5,   461, 186, 'W', 5,   461, 189, 'W', 5,   460, 191, 'W', 5,   460, 194, 'W', 5,   459, 197, 'W', 5,   459, 200, 'W', 5,   458, 203, 'W', 5,   458, 206, 'W', 5,   457, 209, 'W', 5,   457, 212, 'W', 5,   456, 215, 'W', 5,   456, 218, 'W', 5,   456, 221, 'W', 5,   455, 224, 'W', 5,   455, 227, 'W', 5,   454, 230, 'W', 5,   454, 233, 'W', 5,   500, 105, 'W', 5,   498, 107, 'W', 5,   497, 110, 'W', 5,   495, 112, 'W', 5,   494, 115, 'W', 5,   493, 118, 'W', 5,   491, 120, 'W', 5,   490, 123, 'W', 5,   488, 126, 'W', 5,   487, 128, 'W', 5,   486, 131, 'W', 5,   484, 134, 'W', 5,   483, 136, 'W', 5,   481, 139, 'W', 5,   480, 142, 'W', 5,   479, 144, 'W', 5,   477, 147, 'W', 5,   476, 150, 'W', 5,   475, 152, 'W', 5,   473, 155, 'W', 5,   472, 158, 'W', 5,   470, 160, 'W', 5,   469, 163, 'W', 5,   468, 166, 'W', 5,   466, 168, 'W', 5,   465, 171, 'W', 5
        .word 464, 174, 'W', 5,   465, 176, 'W', 5,   466, 179, 'W', 5,   468, 181, 'W', 5,   469, 184, 'W', 5,   471, 187, 'W', 5,   472, 189, 'W', 5,   474, 192, 'W', 5,   475, 195, 'W', 5,   476, 197, 'W', 5,   478, 200, 'W', 5,   479, 202, 'W', 5,   481, 205, 'W', 5,   482, 208, 'W', 5,   484, 210, 'W', 5,   485, 213, 'W', 5,   486, 216, 'W', 5,   488, 218, 'W', 5,   489, 221, 'W', 5,   491, 224, 'W', 5,   492, 226, 'W', 5,   494, 229, 'W', 5,   18, 107, 'R', 13,   21, 107, 'R', 13,   24, 107, 'R', 13,   27, 107, 'R', 13,   30, 107, 'R', 13,   33, 107, 'R', 13,   36, 107, 'R', 13,   39, 107, 'R', 13,   42, 107, 'R', 13,   45, 107, 'R', 13,   48, 107, 'R', 13,   51, 107, 'R', 13,   54, 107, 'R', 13,   57, 107, 'R', 13,   60, 107, 'R', 13,   63, 107, 'R', 13,   66, 107, 'R', 13,   69, 107, 'R', 13,   18, 107, 'R', 13,   18, 110, 'R', 13,   18, 113, 'R', 13,   18, 116, 'R', 13,   18, 119, 'R', 13,   18, 122, 'R', 13,   18, 125, 'R', 13,   18, 128, 'R', 13,   18, 131, 'R', 13,   18, 134, 'R', 13
        .word 18, 137, 'R', 13,   18, 140, 'R', 13,   18, 143, 'R', 13,   18, 146, 'R', 13,   18, 149, 'R', 13,   18, 152, 'R', 13,   18, 155, 'R', 13,   18, 158, 'R', 13,   18, 161, 'R', 13,   18, 164, 'R', 13,   18, 167, 'R', 13,   18, 170, 'R', 13,   18, 173, 'R', 13,   18, 176, 'R', 13,   18, 179, 'R', 13,   18, 182, 'R', 13,   18, 185, 'R', 13,   18, 188, 'R', 13,   18, 191, 'R', 13,   18, 194, 'R', 13,   18, 197, 'R', 13,   18, 200, 'R', 13,   18, 203, 'R', 13,   18, 206, 'R', 13,   18, 209, 'R', 13,   18, 212, 'R', 13,   18, 215, 'R', 13,   18, 218, 'R', 13,   18, 221, 'R', 13,   18, 224, 'R', 13,   18, 227, 'R', 13,   18, 230, 'R', 13,   18, 233, 'R', 13,   18, 236, 'R', 13,   18, 158, 'R', 13,   20, 157, 'R', 13,   23, 157, 'R', 13,   26, 157, 'R', 13,   29, 157, 'R', 13,   32, 157, 'R', 13,   35, 157, 'R', 13,   38, 157, 'R', 13,   41, 157, 'R', 13,   44, 157, 'R', 13,   47, 157, 'R', 13,   50, 157, 'R', 13,   53, 157, 'R', 13,   56, 157, 'R', 13,   59, 157, 'R', 13,   62, 157, 'R', 13
        .word 65, 157, 'R', 13,   68, 157, 'R', 13,   73, 107, 'R', 13,   72, 109, 'R', 13,   72, 112, 'R', 13,   72, 115, 'R', 13,   72, 118, 'R', 13,   72, 121, 'R', 13,   72, 124, 'R', 13,   72, 127, 'R', 13,   72, 130, 'R', 13,   72, 133, 'R', 13,   72, 136, 'R', 13,   72, 139, 'R', 13,   72, 142, 'R', 13,   72, 145, 'R', 13,   72, 148, 'R', 13,   72, 151, 'R', 13,   72, 154, 'R', 13,   18, 158, 'R', 13,   19, 160, 'R', 13,   21, 162, 'R', 13,   23, 165, 'R', 13,   25, 167, 'R', 13,   26, 170, 'R', 13,   28, 172, 'R', 13,   30, 174, 'R', 13,   32, 177, 'R', 13,   34, 179, 'R', 13,   35, 182, 'R', 13,   37, 184, 'R', 13,   39, 186, 'R', 13,   41, 189, 'R', 13,   43, 191, 'R', 13,   44, 194, 'R', 13,   46, 196, 'R', 13,   48, 198, 'R', 13,   50, 201, 'R', 13,   52, 203, 'R', 13,   53, 206, 'R', 13,   55, 208, 'R', 13,   57, 210, 'R', 13,   59, 213, 'R', 13,   60, 215, 'R', 13,   62, 218, 'R', 13,   64, 220, 'R', 13,   66, 222, 'R', 13,   68, 225, 'R', 13,   69, 227, 'R', 13,   71, 230, 'R', 13
        .word 73, 232, 'R', 13,   100, 105, 'R', 13,   103, 105, 'R', 13,   106, 105, 'R', 13,   109, 105, 'R', 13,   112, 105, 'R', 13,   115, 105, 'R', 13,   118, 105, 'R', 13,   121, 105, 'R', 13,   124, 105, 'R', 13,   127, 105, 'R', 13,   130, 105, 'R', 13,   133, 105, 'R', 13,   136, 105, 'R', 13,   139, 105, 'R', 13,   142, 105, 'R', 13,   145, 105, 'R', 13,   148, 105, 'R', 13,   100, 105, 'R', 13,   100, 108, 'R', 13,   100, 111, 'R', 13,   100, 114, 'R', 13,   100, 117, 'R', 13,   100, 120, 'R', 13,   100, 123, 'R', 13,   100, 126, 'R', 13,   100, 129, 'R', 13,   100, 132, 'R', 13,   100, 135, 'R', 13,   100, 138, 'R', 13,   100, 141, 'R', 13,   100, 144, 'R', 13,   100, 147, 'R', 13,   100, 150, 'R', 13,   100, 153, 'R', 13,   100, 156, 'R', 13,   100, 159, 'R', 13,   100, 162, 'R', 13,   100, 165, 'R', 13,   100, 168, 'R', 13,   100, 171, 'R', 13,   100, 174, 'R', 13,   100, 177, 'R', 13,   100, 180, 'R', 13,   100, 183, 'R', 13,   100, 186, 'R', 13,   100, 189, 'R', 13,   100, 192, 'R', 13,   100, 195, 'R', 13,   100, 198, 'R', 13
        .word 100, 201, 'R', 13,   100, 204, 'R', 13,   100, 207, 'R', 13,   100, 210, 'R', 13,   100, 213, 'R', 13,   100, 216, 'R', 13,   100, 219, 'R', 13,   100, 222, 'R', 13,   100, 225, 'R', 13,   100, 228, 'R', 13,   100, 231, 'R', 13,   101, 164, 'R', 13,   103, 163, 'R', 13,   106, 163, 'R', 13,   109, 163, 'R', 13,   112, 163, 'R', 13,   115, 163, 'R', 13,   118, 163, 'R', 13,   121, 163, 'R', 13,   124, 163, 'R', 13,   127, 162, 'R', 13,   130, 162, 'R', 13,   133, 162, 'R', 13,   136, 162, 'R', 13,   139, 162, 'R', 13,   142, 162, 'R', 13,   145, 162, 'R', 13,   100, 234, 'R', 13,   102, 233, 'R', 13,   105, 233, 'R', 13,   108, 233, 'R', 13,   111, 233, 'R', 13,   114, 233, 'R', 13,   117, 233, 'R', 13,   120, 233, 'R', 13,   123, 233, 'R', 13,   126, 233, 'R', 13,   129, 233, 'R', 13,   132, 233, 'R', 13,   135, 233, 'R', 13,   138, 233, 'R', 13,   141, 233, 'R', 13,   144, 233, 'R', 13,   174, 105, 'R', 13,   176, 106, 'R', 13,   179, 107, 'R', 13,   182, 108, 'R', 13,   185, 109, 'R', 13,   187, 110, 'R', 13,   190, 112, 'R', 13
        .word 193, 113, 'R', 13,   196, 114, 'R', 13,   198, 115, 'R', 13,   201, 116, 'R', 13,   204, 117, 'R', 13,   207, 119, 'R', 13,   209, 120, 'R', 13,   212, 121, 'R', 13,   215, 122, 'R', 13,   218, 123, 'R', 13,   220, 124, 'R', 13,   223, 126, 'R', 13,   226, 127, 'R', 13,   174, 105, 'R', 13,   174, 107, 'R', 13,   174, 110, 'R', 13,   174, 113, 'R', 13,   174, 116, 'R', 13,   174, 119, 'R', 13,   174, 122, 'R', 13,   174, 125, 'R', 13,   174, 128, 'R', 13,   174, 131, 'R', 13,   174, 134, 'R', 13,   174, 137, 'R', 13,   174, 140, 'R', 13,   174, 143, 'R', 13,   174, 146, 'R', 13,   174, 149, 'R', 13,   174, 152, 'R', 13,   174, 155, 'R', 13,   174, 158, 'R', 13,   174, 161, 'R', 13,   174, 164, 'R', 13,   174, 167, 'R', 13,   174, 170, 'R', 13,   174, 173, 'R', 13,   174, 176, 'R', 13,   174, 179, 'R', 13,   174, 182, 'R', 13,   174, 185, 'R', 13,   174, 188, 'R', 13,   174, 191, 'R', 13,   174, 194, 'R', 13,   174, 197, 'R', 13,   174, 200, 'R', 13,   174, 203, 'R', 13,   174, 206, 'R', 13,   174, 209, 'R', 13,   174, 212, 'R', 13
        .word 174, 215, 'R', 13,   174, 218, 'R', 13,   174, 221, 'R', 13,   174, 224, 'R', 13,   174, 227, 'R', 13,   174, 230, 'R', 13,   228, 128, 'R', 13,   227, 130, 'R', 13,   227, 133, 'R', 13,   227, 136, 'R', 13,   227, 139, 'R', 13,   227, 142, 'R', 13,   227, 145, 'R', 13,   227, 148, 'R', 13,   227, 151, 'R', 13,   227, 154, 'R', 13,   227, 157, 'R', 13,   227, 160, 'R', 13,   227, 163, 'R', 13,   227, 166, 'R', 13,   227, 169, 'R', 13,   226, 172, 'R', 13,   226, 175, 'R', 13,   226, 178, 'R', 13,   226, 181, 'R', 13,   226, 184, 'R', 13,   226, 187, 'R', 13,   226, 190, 'R', 13,   226, 193, 'R', 13,   226, 196, 'R', 13,   226, 199, 'R', 13,   226, 202, 'R', 13,   226, 205, 'R', 13,   226, 208, 'R', 13,   226, 211, 'R', 13,   226, 214, 'R', 13,   175, 233, 'R', 13,   177, 232, 'R', 13,   180, 231, 'R', 13,   183, 230, 'R', 13,   186, 229, 'R', 13,   189, 228, 'R', 13,   192, 227, 'R', 13,   195, 226, 'R', 13,   197, 225, 'R', 13,   200, 224, 'R', 13,   203, 224, 'R', 13,   206, 223, 'R', 13,   209, 222, 'R', 13,   212, 221, 'R', 13
        .word 215, 220, 'R', 13,   217, 219, 'R', 13,   220, 218, 'R', 13,   223, 217, 'R', 13,
    welcomeTableCount:      .word 1054

    peopleTable: # Table for people body
    # x, y, color, size
        .word 26, 82, 'G', 5,   29, 82, 'G', 5,   32, 82, 'G', 5,   35, 82, 'G', 5,   38, 82, 'G', 5,   41, 82, 'G', 5,   44, 82, 'G', 5,   47, 82, 'G', 5,   50, 82, 'G', 5,   53, 82, 'G', 5
        .word 56, 82, 'G', 5,   59, 82, 'G', 5,   62, 82, 'G', 5,   65, 82, 'G', 5,   68, 82, 'G', 5,   71, 82, 'G', 5,   74, 82, 'G', 5,   77, 82, 'G', 5,   80, 82, 'G', 5,   83, 82, 'G', 5
        .word 86, 82, 'G', 5,   58, 72, 'G', 5,   58, 75, 'G', 5,   58, 78, 'G', 5,   58, 81, 'G', 5,   58, 84, 'G', 5,   58, 87, 'G', 5,   58, 90, 'G', 5,   58, 93, 'G', 5,   58, 96, 'G', 5
        .word 58, 100, 'G', 5,   55, 102, 'G', 5,   53, 104, 'G', 5,   51, 106, 'G', 5,   49, 108, 'G', 5,   47, 110, 'G', 5,   45, 112, 'G', 5,   43, 115, 'G', 5,   41, 117, 'G', 5,   39, 119, 'G', 5
        .word 37, 121, 'G', 5,   35, 123, 'G', 5,   58, 100, 'G', 5,   60, 102, 'G', 5,   62, 104, 'G', 5,   64, 106, 'G', 5,   66, 108, 'G', 5,   68, 110, 'G', 5,   70, 112, 'G', 5,   72, 115, 'G', 5
        .word 74, 117, 'G', 5,   76, 119, 'G', 5,   78, 121, 'G', 5,   80, 123, 'G', 5,
    peopleTableCount:       .word 54

    winFunTable:    # Table for draw win
    # x, y, color, size
        .word 27, 55, 'B', 20,   28, 62, 'G', 20,   29, 70, 'R', 20,   30, 78, 'Y', 20,   31, 86, 'W', 20,   33, 94, 'B', 20,   34, 102, 'G', 20,   35, 110, 'R', 20,   36, 118, 'Y', 20,   37, 126, 'W', 20
        .word 39, 134, 'B', 20,   40, 141, 'G', 20,   41, 149, 'R', 20,   42, 157, 'Y', 20,   43, 165, 'W', 20,   45, 173, 'B', 20,   46, 181, 'G', 20,   47, 189, 'R', 20,   48, 197, 'Y', 20,   50, 205, 'W', 20
        .word 52, 197, 'B', 20,   55, 189, 'G', 20,   57, 182, 'R', 20,   60, 174, 'Y', 20,   62, 167, 'W', 20,   65, 159, 'B', 20,   67, 151, 'G', 20,   70, 144, 'R', 20,   72, 136, 'Y', 20,   75, 129, 'W', 20
        .word 77, 121, 'B', 20,   80, 113, 'G', 20,   82, 106, 'R', 20,   85, 98, 'Y', 20,   87, 91, 'W', 20,   90, 83, 'B', 20,   93, 75, 'G', 20,   95, 68, 'R', 20,   98, 60, 'Y', 20,   100, 55, 'W', 20
        .word 102, 62, 'B', 20,   105, 70, 'G', 20,   107, 77, 'R', 20,   110, 85, 'Y', 20,   112, 92, 'W', 20,   115, 100, 'B', 20,   117, 108, 'G', 20,   120, 115, 'R', 20,   122, 123, 'Y', 20,   125, 130, 'W', 20
        .word 127, 138, 'B', 20,   130, 146, 'G', 20,   132, 153, 'R', 20,   135, 161, 'Y', 20,   137, 168, 'W', 20,   140, 176, 'B', 20,   143, 184, 'G', 20,   145, 191, 'R', 20,   148, 199, 'Y', 20,   150, 205, 'W', 20
        .word 151, 197, 'B', 20,   152, 189, 'G', 20,   154, 181, 'R', 20,   155, 173, 'Y', 20,   156, 165, 'W', 20,   158, 157, 'B', 20,   159, 149, 'G', 20,   160, 141, 'R', 20,   162, 134, 'Y', 20,   163, 126, 'W', 20
        .word 165, 118, 'B', 20,   166, 110, 'G', 20,   167, 102, 'R', 20,   169, 94, 'Y', 20,   170, 86, 'W', 20,   171, 78, 'B', 20,   173, 70, 'G', 20,   174, 63, 'R', 20,   223, 55, 'Y', 20,   231, 55, 'W', 20
        .word 239, 55, 'B', 20,   247, 55, 'G', 20,   255, 55, 'R', 20,   263, 55, 'Y', 20,   271, 55, 'W', 20,   279, 55, 'B', 20,   287, 55, 'G', 20,   295, 55, 'R', 20,   303, 55, 'Y', 20,   311, 55, 'W', 20
        .word 223, 205, 'B', 20,   231, 205, 'G', 20,   239, 205, 'R', 20,   247, 205, 'Y', 20,   255, 205, 'W', 20,   263, 205, 'B', 20,   271, 205, 'G', 20,   279, 205, 'R', 20,   287, 205, 'Y', 20,   295, 205, 'W', 20
        .word 303, 205, 'B', 20,   311, 205, 'G', 20,   273, 55, 'R', 20,   273, 63, 'Y', 20,   273, 71, 'W', 20,   273, 79, 'B', 20,   273, 87, 'G', 20,   273, 95, 'R', 20,   273, 103, 'Y', 20,   273, 111, 'W', 20
        .word 273, 119, 'B', 20,   273, 127, 'G', 20,   273, 135, 'R', 20,   273, 143, 'Y', 20,   273, 151, 'W', 20,   273, 159, 'B', 20,   273, 167, 'G', 20,   273, 175, 'R', 20,   273, 183, 'Y', 20,   273, 191, 'W', 20
        .word 273, 199, 'B', 20,   373, 205, 'G', 20,   373, 197, 'R', 20,   373, 189, 'Y', 20,   373, 181, 'W', 20,   373, 173, 'B', 20,   373, 165, 'G', 20,   373, 157, 'R', 20,   373, 149, 'Y', 20,   373, 141, 'W', 20
        .word 373, 133, 'B', 20,   373, 125, 'G', 20,   373, 117, 'R', 20,   373, 109, 'Y', 20,   373, 101, 'W', 20,   373, 93, 'B', 20,   373, 85, 'G', 20,   373, 77, 'R', 20,   373, 69, 'Y', 20,   373, 61, 'W', 20
        .word 373, 55, 'B', 20,   377, 61, 'G', 20,   381, 68, 'R', 20,   386, 74, 'Y', 20,   390, 81, 'W', 20,   395, 88, 'B', 20,   399, 94, 'G', 20,   404, 101, 'R', 20,   408, 107, 'Y', 20,   413, 114, 'W', 20
        .word 417, 121, 'B', 20,   422, 127, 'G', 20,   426, 134, 'R', 20,   431, 141, 'Y', 20,   435, 147, 'W', 20,   440, 154, 'B', 20,   444, 160, 'G', 20,   449, 167, 'R', 20,   453, 174, 'Y', 20,   458, 180, 'W', 20
        .word 462, 187, 'B', 20,   467, 193, 'G', 20,   471, 200, 'R', 20,   475, 205, 'Y', 20,   475, 197, 'W', 20,   475, 189, 'B', 20,   475, 181, 'G', 20,   475, 173, 'R', 20,   475, 165, 'Y', 20,   475, 157, 'W', 20
        .word 475, 149, 'B', 20,   475, 141, 'G', 20,   475, 133, 'R', 20,   475, 125, 'Y', 20,   475, 117, 'W', 20,   475, 109, 'B', 20,   475, 101, 'G', 20,   475, 93, 'R', 20,   475, 85, 'Y', 20,   475, 77, 'W', 20
        .word 475, 69, 'B', 20,   475, 61, 'G', 20,
    winFunTableCount:       .word 182

    loseTerribleTable:  # Table for draw lose
    # x, y, color, size
        .word 51, 29, 'R', 20,   51, 37, 'R', 20,   51, 45, 'R', 20,   51, 53, 'R', 20,   51, 61, 'R', 20,   51, 69, 'R', 20,   51, 77, 'R', 20,   51, 85, 'R', 20,   51, 93, 'R', 20,   51, 101, 'R', 20
        .word 51, 109, 'R', 20,   51, 117, 'R', 20,   51, 125, 'R', 20,   51, 133, 'R', 20,   51, 141, 'R', 20,   51, 149, 'R', 20,   51, 157, 'R', 20,   51, 165, 'R', 20,   51, 173, 'R', 20,   51, 181, 'R', 20
        .word 51, 189, 'R', 20,   51, 197, 'R', 20,   51, 205, 'R', 20,   59, 205, 'R', 20,   67, 205, 'R', 20,   75, 205, 'R', 20,   83, 205, 'R', 20,   91, 205, 'R', 20,   99, 205, 'R', 20,   107, 205, 'R', 20
        .word 115, 205, 'R', 20,   123, 205, 'R', 20,   131, 205, 'R', 20,   139, 205, 'R', 20,   179, 105, 'R', 20,   179, 113, 'R', 20,   179, 121, 'R', 20,   179, 129, 'R', 20,   179, 137, 'R', 20,   179, 145, 'R', 20
        .word 179, 153, 'R', 20,   179, 161, 'R', 20,   179, 169, 'R', 20,   179, 177, 'R', 20,   179, 185, 'R', 20,   179, 193, 'R', 20,   179, 105, 'R', 20,   187, 105, 'R', 20,   195, 105, 'R', 20,   203, 105, 'R', 20
        .word 211, 105, 'R', 20,   219, 105, 'R', 20,   227, 105, 'R', 20,   235, 105, 'R', 20,   243, 105, 'R', 20,   251, 105, 'R', 20,   259, 105, 'R', 20,   179, 205, 'R', 20,   187, 205, 'R', 20,   195, 205, 'R', 20
        .word 203, 205, 'R', 20,   211, 205, 'R', 20,   219, 205, 'R', 20,   227, 205, 'R', 20,   235, 205, 'R', 20,   243, 205, 'R', 20,   251, 205, 'R', 20,   259, 205, 'R', 20,   269, 205, 'R', 20,   269, 197, 'R', 20
        .word 269, 189, 'R', 20,   269, 181, 'R', 20,   269, 173, 'R', 20,   269, 165, 'R', 20,   269, 157, 'R', 20,   269, 149, 'R', 20,   269, 141, 'R', 20,   269, 133, 'R', 20,   269, 125, 'R', 20,   269, 117, 'R', 20
        .word 300, 105, 'R', 20,   308, 105, 'R', 20,   316, 105, 'R', 20,   324, 105, 'R', 20,   332, 105, 'R', 20,   340, 105, 'R', 20,   348, 105, 'R', 20,   356, 105, 'R', 20,   364, 105, 'R', 20,   372, 105, 'R', 20
        .word 300, 105, 'R', 20,   300, 113, 'R', 20,   300, 121, 'R', 20,   300, 129, 'R', 20,   300, 137, 'R', 20,   300, 145, 'R', 20,   300, 155, 'R', 20,   308, 155, 'R', 20,   316, 155, 'R', 20,   324, 155, 'R', 20
        .word 332, 155, 'R', 20,   340, 155, 'R', 20,   348, 155, 'R', 20,   356, 155, 'R', 20,   364, 155, 'R', 20,   372, 155, 'R', 20,   377, 155, 'R', 20,   377, 163, 'R', 20,   377, 171, 'R', 20,   377, 179, 'R', 20
        .word 377, 187, 'R', 20,   377, 195, 'R', 20,   300, 205, 'R', 20,   308, 205, 'R', 20,   316, 205, 'R', 20,   324, 205, 'R', 20,   332, 205, 'R', 20,   340, 205, 'R', 20,   348, 205, 'R', 20,   356, 205, 'R', 20
        .word 364, 205, 'R', 20,   372, 205, 'R', 20,   412, 105, 'R', 20,   420, 105, 'R', 20,   428, 105, 'R', 20,   436, 105, 'R', 20,   444, 105, 'R', 20,   452, 105, 'R', 20,   460, 105, 'R', 20,   468, 105, 'R', 20
        .word 476, 105, 'R', 20,   412, 105, 'R', 20,   412, 113, 'R', 20,   412, 121, 'R', 20,   412, 129, 'R', 20,   412, 137, 'R', 20,   412, 145, 'R', 20,   412, 153, 'R', 20,   412, 161, 'R', 20,   412, 169, 'R', 20
        .word 412, 177, 'R', 20,   412, 185, 'R', 20,   412, 193, 'R', 20,   412, 155, 'R', 20,   420, 155, 'R', 20,   428, 155, 'R', 20,   436, 155, 'R', 20,   444, 155, 'R', 20,   452, 155, 'R', 20,   460, 155, 'R', 20
        .word 468, 155, 'R', 20,   476, 155, 'R', 20,   412, 205, 'R', 20,   420, 205, 'R', 20,   428, 205, 'R', 20,   436, 205, 'R', 20,   444, 205, 'R', 20,   452, 205, 'R', 20,   460, 205, 'R', 20,   468, 205, 'R', 20
        .word 476, 205, 'R', 20,
    loseTerribleTableCount: .word 161


.text
# Procedure: calculateAddress:
# Convert x and y coordinate to address
# $a0 = x coordinate (0-512)
# $a1 = y coordinate (0-256)
# $v0 = memory address
calculateAddress:
# BEGIN
    # Save return address
    addi $sp, $sp, -4  # Allocate stack space
    sw $ra, 0($sp)     # Save $ra on stack

# BODY
    # CALCULATIONS
    sll $a1, $a1, 9     # Multiply $a1 by 512
    add $a0, $a0, $a1   # Add $a1 to $a0
    sll $a0, $a0, 2     # Multiply $a0 by 4
    addi $v0, $a0, 0x10040000   # Add base address for display + $a0 to $v0

# RETURN
    # Restore return address
    lw $ra, 0($sp)     # Load $ra from stack
    addi $sp, $sp, 4   # Deallocate stack space

    jr $ra  # Return from procedure


# Return the color value in $v1 based on the argument
# Argument: $a2: contains character B, G, R, Y, or 0
# Return: $v1: 32-bit color value
getColor:
# BEGIN
    # Save return address
    addi $sp, $sp, -4  # Allocate stack space
    sw $ra, 0($sp)     # Save $ra on stack

# BODY
    la $t0, colorTable  # Load base address of color table to $t0

    color_table_loop:
        lw $t1, 0($t0)  # Load the next byte into $t1, this byte has the color character
        beq $t1, $a2, load_color_value
        addi $t0, $t0, 8  # Move 2 words up to get the next color character
        b color_table_loop

    load_color_value:
        lw $v1, 4($t0)  # Place the whole word in $v1

# RETURN
    # Restore return address
    lw $ra, 0($sp)     # Load $ra from stack
    addi $sp, $sp, 4   # Deallocate stack space

    jr $ra  # Return from procedure


# Procedure: drawDot:
# Draw a dot on the bitmap display
# $a0 = x coordinate (0-31)
# $a1 = y coordinate (0-31)
# $a2 = color character B, G, R, Y, or 0
drawDot:
# BEGIN
    # MAKE ROOM ON STACK
    addi $sp, $sp, -8   # Make room on stack for 2 words
    sw $ra, 4($sp)      # Store $ra on element 1 of stack
    sw $a2, 0($sp)      # Store $a2 on element 0 of stack

# BODY
    # CALCULATE ADDRESS
    jal calculateAddress  # returns address of pixel in $v0
    lw $a2, 0($sp)      # Restore $a2 from stack
    sw $v0, 0($sp)      # Save $v0 on element 0 of stack

    # GET COLOR
    jal getColor       # Returns color in $v1
    lw $v0, 0($sp)      # Restores $v0 from stack

# RETURN
    # MAKE DOT AND RESTORE $RA
    sw $v1, 0($v0)      # Make dot
    lw $ra, 4($sp)      # Restore $ra from stack
    addi $sp, $sp, 8   # Readjust stack

    jr $ra       # Return


# Procedure: drawHorzLine:
# Draw a horizontal line on the bitmap display
# $a0 = x coordinate (0-31)
# $a1 = y coordinate (0-31)
# $a2 = color character B, G, R, Y, or 0
# $a3 = length of the line
drawHorzLine:
# BEGIN
    # MAKE ROOM ON STACK AND SAVE REGISTERS
    addi $sp, $sp, -16   # Make room on stack for 4 words
    sw $ra, 12($sp)      # Store $ra on element 4 of stack
    sw $a0, 0($sp)      # Store $a0 on element 0 of stack
    sw $a1, 4($sp)      # Store $a1 on element 1 of stack
    sw $a2, 8($sp)      # Store $a2 on element 2 of stack

# BODY
    # HORIZONTAL LOOP
    horz_line_loop:
    jal drawDot      # Jump and Link to drawDot

    # RESTORE REGISTERS
    lw $a0, 0($sp)      # Restore $a0 from stack
    lw $a1, 4($sp)      # Restore $a1 from stack
    lw $a2, 8($sp)      # Restore $a2 from stack

    # INCREMENT VALUES
    addi $a0, $a0, 1   # Increment x by 1
    sw $a0, 0($sp)      # Store $a0 on element 0 of stack
    addi $a3, $a3, -1   # Decrement length of line
    bne $a3, $0, horz_line_loop   # If length is not 0, loop

# RETURN
    # RESTORE $RA
    lw $ra, 12($sp)      # Restore $ra from stack
    addi $sp, $sp, 16   # Readjust stack

    jr $ra      # Return


# Procedure: drawVertLine:
# Draw a vertical line on the bitmap display
# $a0 = x coordinate (0-31)
# $a1 = y coordinate (0-31)
# $a2 = color character B, G, R, Y, or 0
# $a3 = length of the line (1-32)
drawVertLine:
# BEGIN
    # MAKE ROOM ON STACK AND SAVE REGISTERS
    addi $sp, $sp, -16   # Make room on stack for 4 words
    sw $ra, 12($sp)      # Store $ra on element 4 of stack
    sw $a0, 0($sp)      # Store $a0 on element 0 of stack
    sw $a1, 4($sp)      # Store $a1 on element 1 of stack
    sw $a2, 8($sp)      # Store $a2 on element 2 of stack

# BODY
    # VERTICAL LOOP
    vert_line_loop:
    jal drawDot      # Jump and Link to drawDot

    # RESTORE REGISTERS
    lw $a0, 0($sp)      # Restore $a0 from stack
    lw $a1, 4($sp)      # Restore $a1 from stack
    lw $a2, 8($sp)      # Restore $a2 from stack

    # INCREMENT VALUES
    addi $a1, $a1, 1   # Increment y by 1
    sw $a1, 4($sp)      # Store $a1 on element 1 of stack
    addi $a3, $a3, -1   # Decrement length of line
    bne $a3, $0, vert_line_loop   # If length is not 0, loop

# RETURN
    # RESTORE $RA
    lw $ra, 12($sp)      # Restore $ra from stack
    addi $sp, $sp, 16   # Readjust stack

    jr $ra      # Return


# Procedure: drawLine:
# Draw a line on the bitmap display
# Attention: x2 should greater or equal then x1, and y2 >= y1
# If not, then use $s1 = 1 to tell me symmetry draw
# $a0 = x1 coordinate (0-512)
# $a1 = y1 coordinate (0-255)
# $a2 = x2 coordinate (0-512)
# $a3 = y2 coordinate (0-255)
# $s0 = color character B, G, R, Y, or 0
# $s1 = if symmetry ( 1 for symmetry )
drawLine:
# BEGIN
    # MAKE ROOM ON STACK AND SAVE REGISTERS
    addi $sp, $sp, -32   # Make room on stack for 8 words
    sw $ra, 24($sp)      # Store $ra on element 6 of stack
    sw $a0, 0($sp)      # Store $a0 on element 0 of stack
    sw $a1, 4($sp)      # Store $a1 on element 1 of stack
    sw $a2, 8($sp)      # Store $a2 on element 2 of stack
    sw $a3, 12($sp)      # Store $a3 on element 3 of stack
    sw $s0, 16($sp)      # Store $s0 on element 4 of stack
    sw $s1, 20($sp)         # Store $s1 on element 5 of stack

# BODY
    # x1: 0($sp), y1: 4($sp)
    # x2: 8($sp), y2: 16($sp)

    # complete here: calculate for next x and y coordinates using slope-intercept form of a line equation y = mx + b where m is the slope and b is the y-intercept.
    subu $t0, $a2, $a0   # get x2 - x1
    subu $t1, $a3, $a1   # get y2 - y1
    beqz $t1, horz_line   # if y2 - y1 is zero
    divu $t3,$t1,$t0     # get slope by dividing y2 - y1 by x2 - x1
    bne $t3, 0, not_zero
    li $t3, 1   

    not_zero:
    sw $t3, 28($sp) # ???????

    # LINE LOOP
    line_loop:
        lw $s1, 20($sp)
        lw $a0, 0($sp)
        bne $s1, 1, not_symmetry

        li $a1, 512
        sub $a0, $a1, $a0

    not_symmetry:
        lw $a1, 4($sp)
        lw $a2, 16($sp)     # get color
        jal drawDot      # Jump and Link to drawDot

        # RESTORE REGISTERS
        lw $a0, 0($sp)      # Restore x1 from stack
        lw $a1, 4($sp)      # Restore y1 from stack
        lw $a2, 8($sp)      # Restore x2 from stack
        lw $a3, 12($sp)      # Restore y2 from stack
        lw $t3, 28($sp)

        bgt $a0, $a2, vert_line
        bgt $a1, $a3, horz_line

        # INCREMENT VALUES
        add $a0, $a0, 1
        sw $a0, 0($sp)
        add $a1, $a1, $t3
        sw $a1, 4($sp)
        j line_loop

    vert_line:
        lw $a0,8($sp)         # load x coordinate 
        lw $a1,4($sp)         # load start y coordinate 
        lw $a3,12($sp)        # load end y coordinate 
        bgt $a1, $a3, line_loop_end

        sub $a3, $a3, $a1
        lw $a2,16($sp)        # load color 
        jal drawVertLine         # call drawVertLine procedure 
        j line_loop_end          # jump to end of loop 

    horz_line:
        lw $a0,4($sp)         # load start x coordinate 
        lw $a3,8($sp)         # load end x coordinate 
        bgt $a0, $a3, line_loop_end

        sub $a3, $a3, $a0
        lw $a1,12($sp)        # load y coordinate 
        lw $a2,16($sp)        # load color 
        jal drawHorzLine         # call drawHorzLine procedure 
        j line_loop_end          # jump to end of loop 

# RETURN
line_loop_end:
    # RESTORE $RA
    lw $ra, 24($sp)      # Restore $ra from stack
    addi $sp, $sp, 32   # Readjust stack

    jr $ra      # Return


# Procedure: drawBox:
# Draw a box on the bitmap display
# $a0 = x coordinate (0-31)
# $a1 = y coordinate (0-31)
# $a2 = color character B, G, R, Y, or 0
# $a3 = size of box (1-32)
drawBox:
# BEGIN
    # MAKE ROOM ON STACK AND SAVE REGISTERS
    addi $sp, $sp, -24   # Make room on stack for 5 words
    sw $ra, 12($sp)      # Store $ra on element 4 of stack
    sw $a0, 0($sp)      # Store $a0 on element 0 of stack
    sw $a1, 4($sp)      # Store $a1 on element 1 of stack
    sw $a2, 8($sp)      # Store $a2 on element 2 of stack
    sw $a3, 20($sp)     # Store $a3 on element 5 of stack
    move $s0, $a3       # Copy $a3 to temp register
    sw $s0, 16($sp)     # Store $s0 on element 5 of stack

# BEGIN
    box_loop:
    jal drawHorzLine   # Jump and link to drawHorzLine

    # RESTORE REGISTERS
    lw $a0, 0($sp)      # Restore $a0 from stack
    lw $a1, 4($sp)      # Restore $a1 from stack
    lw $a2, 8($sp)      # Restore $a2 from stack
    lw $a3, 20($sp)     # Restore $a3 from stack
    lw $s0, 16($sp)     # Restore $s0 from stack

    # INCREMENT VALUES
    addi $a1, $a1, 1   # Increment y by 1
    sw $a1, 4($sp)      # Store $a1 on element 1 of stack
    addi $s0, $s0, -1   # Decrement counter
    sw $s0, 16($sp)     # Store $s0 on element 5 of stack
    bne $s0, $0, box_loop   # If counter is not 0, loop

# RETURN
    # RESTORE $RA
    lw $ra, 12($sp)      # Restore $ra from stack
    addi $sp, $sp, 24   # Readjust stack
    addi $s0, $s0, 0   # Reset $s0

    jr $ra      # Return


# Procedure: drawRound:
# Draw a Round on the bitmap display
# $a0 = x coordinate (0-31)
# $a1 = y coordinate (0-31)
# $a2 = color character B, G, R, Y, or 0
drawRound:
# BEGIN
    # MAKE ROOM ON STACK AND SAVE REGISTERS
    addi $sp, $sp, -24   # Make room on stack for 5 words
    sw $ra, 12($sp)      # Store $ra on element 4 of stack
    sw $a0, 0($sp)      # Store $a0 on element 0 of stack
    sw $a1, 4($sp)      # Store $a1 on element 1 of stack
    sw $a2, 8($sp)      # Store $a2 on element 2 of stack
    li $s0, 0
    sw $s0, 16($sp)     # Store $s0 on element 5 of stack

# BEGIN
    Round_loop:
    la $t0, roundTable
    add $t0, $t0, $s0
    lb $a3, 0($t0)
    sub $a0, $a0, $a3
    sll $a3, $a3, 1

    jal drawHorzLine   # Jump and link to drawHorzLine

    # RESTORE REGISTERS
    lw $a0, 0($sp)      # Restore $a0 from stack
    lw $a1, 4($sp)      # Restore $a1 from stack
    lw $a2, 8($sp)      # Restore $a2 from stack

    lw $s0, 16($sp)     # Restore $s0 from stack

    # INCREMENT VALUES
    addi $a1, $a1, 1   # Increment y by 1
    sw $a1, 4($sp)      # Store $a1 on element 1 of stack
    addi $s0, $s0, 1
    sw $s0, 16($sp)     # Store $s0 on element 5 of stack
    lw $t0, diameter
    bne $s0, $t0, Round_loop

# RETURN
    # RESTORE $RA
    lw $ra, 12($sp)      # Restore $ra from stack
    addi $sp, $sp, 24   # Readjust stack
    addi $s0, $s0, 0   # Reset $s0

    jr $ra      # Return


.data
        .word   0 : 40
Stack:

Colors: .word   0x000000        # background color (black)
        .word   0xffffff        # foreground color (white)

DigitTable:
        .byte   ' ', 0,0,0,0,0,0,0,0,0,0,0,0
        .byte   '0', 0x7e,0xff,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xff,0x7e
        .byte   '1', 0x38,0x78,0xf8,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18
        .byte   '2', 0x7e,0xff,0x83,0x06,0x0c,0x18,0x30,0x60,0xc0,0xc1,0xff,0x7e
        .byte   '3', 0x7e,0xff,0x83,0x03,0x03,0x1e,0x1e,0x03,0x03,0x83,0xff,0x7e
        .byte   '4', 0xc3,0xc3,0xc3,0xc3,0xc3,0xff,0x7f,0x03,0x03,0x03,0x03,0x03
        .byte   '5', 0xff,0xff,0xc0,0xc0,0xc0,0xfe,0x7f,0x03,0x03,0x83,0xff,0x7f
        .byte   '6', 0xc0,0xc0,0xc0,0xc0,0xc0,0xfe,0xfe,0xc3,0xc3,0xc3,0xff,0x7e
        .byte   '7', 0x7e,0xff,0x03,0x06,0x06,0x0c,0x0c,0x18,0x18,0x30,0x30,0x60
        .byte   '8', 0x7e,0xff,0xc3,0xc3,0xc3,0x7e,0x7e,0xc3,0xc3,0xc3,0xff,0x7e
        .byte   '9', 0x7e,0xff,0xc3,0xc3,0xc3,0x7f,0x7f,0x03,0x03,0x03,0x03,0x03
        .byte   '+', 0x00,0x00,0x00,0x18,0x18,0x7e,0x7e,0x18,0x18,0x00,0x00,0x00
        .byte   '-', 0x00,0x00,0x00,0x00,0x00,0x7e,0x7e,0x00,0x00,0x00,0x00,0x00
        .byte   '*', 0x00,0x00,0x00,0x66,0x3c,0x18,0x18,0x3c,0x66,0x00,0x00,0x00
        .byte   '/', 0x00,0x00,0x18,0x18,0x00,0x7e,0x7e,0x00,0x18,0x18,0x00,0x00
        .byte   '=', 0x00,0x00,0x00,0x00,0x7e,0x00,0x7e,0x00,0x00,0x00,0x00,0x00
        .byte   'A', 0x18,0x3c,0x66,0xc3,0xc3,0xc3,0xff,0xff,0xc3,0xc3,0xc3,0xc3
        .byte   'B', 0xfc,0xfe,0xc3,0xc3,0xc3,0xfe,0xfe,0xc3,0xc3,0xc3,0xfe,0xfc
        .byte   'C', 0x7e,0xff,0xc1,0xc0,0xc0,0xc0,0xc0,0xc0,0xc0,0xc1,0xff,0x7e
        .byte   'D', 0xfc,0xfe,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xfe,0xfc
        .byte   'E', 0xff,0xff,0xc0,0xc0,0xc0,0xfe,0xfe,0xc0,0xc0,0xc0,0xff,0xff
        .byte   'F', 0xff,0xff,0xc0,0xc0,0xc0,0xfe,0xfe,0xc0,0xc0,0xc0,0xc0,0xc0
# add additional characters here....
# first byte is the ascii character
# next 12 bytes are the pixels that are "on" for each of the 12 lines
        .byte    0, 0,0,0,0,0,0,0,0,0,0,0,0

#  0x80----  ----0x08
#  0x40--- || ---0x04
#  0x20-- |||| --0x02
#  0x10- |||||| -0x01
#       ||||||||
#       84218421

#   1   ...xx...      0x18
#   2   ..xxxx..      0x3c
#   3   .xx..xx.      0x66
#   4   xx....xx      0xc3
#   5   xx....xx      0xc3
#   6   xx....xx      0xc3
#   7   xxxxxxxx      0xff
#   8   xxxxxxxx      0xff
#   9   xx....xx      0xc3
#  10   xx....xx      0xc3
#  11   xx....xx      0xc3
#  12   xx....xx      0xc3

.text
# OutText: display ascii characters on the bit mapped display
# $a0 = horizontal pixel co-ordinate (0-512)
# $a1 = vertical pixel co-ordinate (0-255)
# $a2 = pointer to asciiz text (to be displayed)
OutText:
        addiu   $sp, $sp, -24
        sw      $ra, 20($sp)

        li      $t8, 1          # line number in the digit array (1-12)
_text1:
        la      $t9, 0x10040000 # get the memory start address
        sll     $t0, $a0, 2     # assumes mars was configured as 256 x 256
        addu    $t9, $t9, $t0   # and 1 pixel width, 1 pixel height
        sll     $t0, $a1, 11    # (a0 * 4) + (a1 * 4 * 256)
        addu    $t9, $t9, $t0   # t9 = memory address for this pixel

        move    $t2, $a2        # t2 = pointer to the text string
_text2:
        lb      $t0, 0($t2)     # character to be displayed
        addiu   $t2, $t2, 1     # last character is a null
        beq     $t0, $zero, _text9

        la      $t3, DigitTable # find the character in the table
_text3:
        lb      $t4, 0($t3)     # get an entry from the table
        beq     $t4, $t0, _text4
        beq     $t4, $zero, _text4
        addiu   $t3, $t3, 13    # go to the next entry in the table
        j       _text3
_text4:
        addu    $t3, $t3, $t8   # t8 is the line number
        lb      $t4, 0($t3)     # bit map to be displayed

        sw      $zero, 0($t9)   # first pixel is black
        addiu   $t9, $t9, 4

        li      $t5, 8          # 8 bits to go out
_text5:
        la      $t7, Colors
        lw      $t7, 0($t7)     # assume black
        andi    $t6, $t4, 0x80  # mask out the bit (0=black, 1=white)
        beq     $t6, $zero, _text6
        la      $t7, Colors     # else it is white
        lw      $t7, 4($t7)
_text6:
        sw      $t7, 0($t9)     # write the pixel color
        addiu   $t9, $t9, 4     # go to the next memory position
        sll     $t4, $t4, 1     # and line number
        addiu   $t5, $t5, -1    # and decrement down (8,7,...0)
        bne     $t5, $zero, _text5

        sw      $zero, 0($t9)   # last pixel is black
        addiu   $t9, $t9, 4
        j       _text2          # go get another character

_text9:
        addiu   $a1, $a1, 1     # advance to the next line
        addiu   $t8, $t8, 1     # increment the digit array offset (1-12)
        bne     $t8, 13, _text1

        lw      $ra, 20($sp)
        addiu   $sp, $sp, 24
        jr      $ra


	########################################################################
	#   Description:
	#       flushBlockFIFO SPIM exception handler
	#       Derived from the default exception handler in the SPIM S20
	#       distribution.
	#
	#   History:
	#       Dec 2009    J Bacon
	
	########################################################################
	# Exception handling code.  This must go first!
	
			.kdata
	__start_msg_:   .asciiz "  Exception "
	__end_msg_:     .asciiz " occurred and ignored\n"
	
	# Messages for each of the 5-bit exception codes
	__exc0_msg:     .asciiz "  [Interrupt] "
	__exc1_msg:     .asciiz "  [TLB]"
	__exc2_msg:     .asciiz "  [TLB]"
	__exc3_msg:     .asciiz "  [TLB]"
	__exc4_msg:     .asciiz "  [Address error in inst/data fetch] "
	__exc5_msg:     .asciiz "  [Address error in store] "
	__exc6_msg:     .asciiz "  [Bad instruction address] "
	__exc7_msg:     .asciiz "  [Bad data address] "
	__exc8_msg:     .asciiz "  [Error in syscall] "
	__exc9_msg:     .asciiz "  [Breakpoint] "
	__exc10_msg:    .asciiz "  [Reserved instruction] "
	__exc11_msg:    .asciiz ""
	__exc12_msg:    .asciiz "  [Arithmetic overflow] "
	__exc13_msg:    .asciiz "  [Trap] "
	__exc14_msg:    .asciiz ""
	__exc15_msg:    .asciiz "  [Floating point] "
	__exc16_msg:    .asciiz ""
	__exc17_msg:    .asciiz ""
	__exc18_msg:    .asciiz "  [Coproc 2]"
	__exc19_msg:    .asciiz ""
	__exc20_msg:    .asciiz ""
	__exc21_msg:    .asciiz ""
	__exc22_msg:    .asciiz "  [MDMX]"
	__exc23_msg:    .asciiz "  [Watch]"
	__exc24_msg:    .asciiz "  [Machine check]"
	__exc25_msg:    .asciiz ""
	__exc26_msg:    .asciiz ""
	__exc27_msg:    .asciiz ""
	__exc28_msg:    .asciiz ""
	__exc29_msg:    .asciiz ""
	__exc30_msg:    .asciiz "  [Cache]"
	__exc31_msg:    .asciiz ""
	
	__level_msg:    .asciiz "Interrupt mask: "
	
	
	#########################################################################
	# Lookup table of exception messages
	__exc_msg_table:
		.word   __exc0_msg, __exc1_msg, __exc2_msg, __exc3_msg, __exc4_msg
		.word   __exc5_msg, __exc6_msg, __exc7_msg, __exc8_msg, __exc9_msg
		.word   __exc10_msg, __exc11_msg, __exc12_msg, __exc13_msg, __exc14_msg
		.word   __exc15_msg, __exc16_msg, __exc17_msg, __exc18_msg, __exc19_msg
		.word   __exc20_msg, __exc21_msg, __exc22_msg, __exc23_msg, __exc24_msg
		.word   __exc25_msg, __exc26_msg, __exc27_msg, __exc28_msg, __exc29_msg
		.word   __exc30_msg, __exc31_msg
	
	# Variables for save/restore of registers used in the handler
	save_v0:    .word   0
	save_a0:    .word   0
	save_at:    .word   0
	
	
	#########################################################################
	# This is the exception handler code that the processor runs when
	# an exception occurs. It only prints some information about the
	# exception, but can serve as a model of how to write a handler.
	#
	# Because this code is part of the kernel, it can use $k0 and $k1 without
	# saving and restoring their values.  By convention, they are treated
	# as temporary registers for kernel use.
	#
	# On the MIPS-1 (R2000), the exception handler must be at 0x80000080
	# This address is loaded into the program counter whenever an exception
	# occurs.  For the MIPS32, the address is 0x80000180.
	# Select the appropriate one for the mode in which SPIM is compiled.
	
		.ktext  0x80000180
	
		# Save ALL registers modified in this handler, except $k0 and $k1
		# This includes $t* since the user code does not explicitly
		# call this handler.  $sp cannot be trusted, so saving them to
		# the stack is not an option.  This routine is not reentrant (can't
		# be called again while it is running), so we can save registers
		# to static variables.
		sw      $v0, save_v0
		sw      $a0, save_a0
	
		# $at is the temporary register reserved for the assembler.
		# It may be modified by pseudo-instructions in this handler.
		# Since an interrupt could have occurred during a pseudo
		# instruction in user code, $at must be restored to ensure
		# that that pseudo instruction completes correctly.
		.set    noat
		sw      $at, save_at
		.set    at
	
		# Determine cause of the exception
		mfc0    $k0, $13        # Get cause register from coprocessor 0
		srl     $a0, $k0, 2     # Extract exception code field (bits 2-6)
		andi    $a0, $a0, 0x1f
		
		# Check for program counter issues (exception 6)
		bne     $a0, 6, ok_pc
		nop
	
		mfc0    $a0, $14        # EPC holds PC at moment exception occurred
		andi    $a0, $a0, 0x3   # Is EPC word-aligned (multiple of 4)?
		beqz    $a0, ok_pc
		nop
	
		# Bail out if PC is unaligned
		# Normally you don't want to do syscalls in an exception handler,
		# but this is MARS and not a real computer
		li      $v0, 4
		la      $a0, __exc3_msg
		syscall
		li      $v0, 10
		syscall
	
	ok_pc:
		mfc0    $k0, $13
		srl     $a0, $k0, 2     # Extract exception code from $k0 again
		andi    $a0, $a0, 0x1f
		bnez    $a0, non_interrupt  # Code 0 means exception was an interrupt
		nop
	
		# External interrupt handler
		# Don't skip instruction at EPC since it has not executed.
		# Interrupts occur BEFORE the instruction at PC executes.
		# Other exceptions occur during the execution of the instruction,
		# hence for those increment the return address to avoid
		# re-executing the instruction that caused the exception.
	
	     # check if we are in here because of a character on the keyboard simulator
		 # go to nochar if some other interrupt happened
		 
		 # get the character from memory
		 # store it to a queue somewhere to be dealt with later by normal code

        andi $a0, $k0, 0x100 # check if keyboard interrupt
        beqz $a0, return # if not keyboard, return
        nop

# Using interrupts to store content in FIFO queues
ifChar: 
        lui $a0, 0xffff     # load keyboard char
        lw $v0, 4($a0)

        beq $v0, 'W', turn_people_up
        beq $v0, 'w', turn_people_up
        beq $v0, 'S', turn_people_down
        beq $v0, 's', turn_people_down
        j ifChar_end

        turn_people_up:
        la $t0, peopleState
        li $t1, 'U'
        sw $t1, ($t0)

        # la $a0, 'U'
        # li $v0, 11
        # syscall

        j ifChar_end

        turn_people_down:
        la $t0, peopleState
        li $t1, 'D'
        sw $t1, ($t0)

        # la $a0, 'D'
        # li $v0, 11
        # syscall

        j ifChar_end

        ifChar_end:
		j	return
	
nochar:
		# not a character
		# Print interrupt level
		# Normally you don't want to do syscalls in an exception handler,
		# but this is MARS and not a real computer
		li      $v0, 4          # print_str
		la      $a0, __level_msg
		syscall
		
		li      $v0, 1          # print_int
		mfc0    $k0, $13        # Cause register
		srl     $a0, $k0, 11    # Right-justify interrupt level bits
		syscall
		
		li      $v0, 11         # print_char
		li      $a0, 10         # Line feed
		syscall
		
		j       return
	
	non_interrupt:
		# Print information about exception.
		# Normally you don't want to do syscalls in an exception handler,
		# but this is MARS and not a real computer
		li      $v0, 4          # print_str
		la      $a0, __start_msg_
		syscall
	
		li      $v0, 1          # print_int
		mfc0    $k0, $13        # Extract exception code again
		srl     $a0, $k0, 2
		andi    $a0, $a0, 0x1f
		syscall
	
		# Print message corresponding to exception code
		# Exception code is already shifted 2 bits from the far right
		# of the cause register, so it conveniently extracts out as
		# a multiple of 4, which is perfect for an array of 4-byte
		# string addresses.
		# Normally you don't want to do syscalls in an exception handler,
		# but this is MARS and not a real computer
		li      $v0, 4          # print_str
		mfc0    $k0, $13        # Extract exception code without shifting
		andi    $a0, $k0, 0x7c
		lw      $a0, __exc_msg_table($a0)
		nop
		syscall
	
		li      $v0, 4          # print_str
		la      $a0, __end_msg_
		syscall
	
		# Return from (non-interrupt) exception. Skip offending instruction
		# at EPC to avoid infinite loop.
		mfc0    $k0, $14
		addiu   $k0, $k0, 4
		mtc0    $k0, $14
	
	return:
		# Restore registers and reset processor state
		lw      $v0, save_v0    # Restore other registers
		lw      $a0, save_a0
	
		.set    noat            # Prevent assembler from modifying $at
		lw      $at, save_at
		.set    at
	
		mtc0    $zero, $13      # Clear Cause register
	
		# Re-enable interrupts, which were automatically disabled
		# when the exception occurred, using read-modify-write cycle.
		mfc0    $k0, $12        # Read status register
		andi    $k0, 0xfffd     # Clear exception level bit
		ori     $k0, 0x0001     # Set interrupt enable bit
		mtc0    $k0, $12        # Write back
	
		# Return from exception on MIPS32:
		eret
	
	
	#########################################################################
	# Standard startup code.  Invoke the routine "main" with arguments:
	# main(argc, argv, envp)
	
		.text
		.globl __start
	__start:
		lw      $a0, 0($sp)     # argc = *$sp
		addiu   $a1, $sp, 4     # argv = $sp + 4
		addiu   $a2, $sp, 8     # envp = $sp + 8
		sll     $v0, $a0, 2     # envp += size of argv array
		addu    $a2, $a2, $v0
		jal     main
		nop

		li      $v0, 10         # exit
		syscall
	
		.globl __eoth
	__eoth:.data
