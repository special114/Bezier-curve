# This program draws quadratic Bezier curve in given bmp file.
# All the operations are explained later on.
# author: Rafał Surdej
# 04.2020
	
#--------------------- READ BELOW BEFORE RUNNING --------------------#


# Program draws coordinate system in the bmp file. X coordinate is scaled with the width of the file so it is always from
# range <-32, 32>. Y coordinate diplayed range may vary depending on the height of the image (it will also be from -32 to 32
# it the image is a square). However, user can provide smaller or bigger values of points' coordinates to change the path of
# the curve. It will result in drawing only those points whose coordinates fit the range of image pixels.
#
# About the bmp file:
#
# It has to be RGB type file with 24 bits per pixel. Offset to pixel array has to be 54 bytes. Maximum size of the file is 4MB.
# Width and height of the file shouldn't be greater than 1023 pixels. If they are bigger then the coordinates will have to
# decrease in value. Otherwise program will behave indefinetly.

			

	.data
in_file: 	.asciiz "input50.bmp"
out_file:	.asciiz "output.bmp"
prompt:		.asciiz "Enter coordinates of 3 points.Press enter after every coordinate typed.\nIn order to get the best effect type numbers from range <-32,32>\n"
first_point_prompt:	.asciiz "First point: coordinates should be from range <-128,128>\n"
second_point_prompt:	.asciiz "Second point: coordinates should be from range <-128,128>\n"
third_point_prompt:	.asciiz "Third point: coordinates should be from range <-128,128>\n"

open_in_file_err:	.asciiz "Can't open input file. Exiting.\n"
open_out_file_err:	.asciiz "Can't open output file. Exiting.\n"
read_from_in_file_err:	.asciiz "Reading from file failure. Exiting.\n"
store_to_out_file_err:	.asciiz "Storing to file failure. Exiting.\n"


.align 2
data_holder: 	.space 20	# will temporarly store data read from file
.align 1
header:		.space 54

	.text
	.globl main
	
	# Contents of the registers used in the program
	
	# Constant
	
	# s0 = input file descriptor
	# s1 = image width
	# s2 = image height
	# s3 = pixel array size
	# s4 = padding
	# s5 = allocated memory address
	# s6 = output file desrciptor
	
	# t2 = P0x
	# t3 = P0y
	# t4 = P1x
	# t5 = P1y
	# t6 = P2x
	# t7 = P2y
	
	
	# Variable
	
	# While reading data
	# t0-t1 and  t8-t9 are used to store temporaty data, a0-a3 are argument for syscalls
	
	# While calculating points:
	# t0 = x coordinate of the calculated point
	# t1 = y coordinate of the calculated point
	# t8 = t parameter
	# t9 = 1-t; calculations' loop iterator
	# a2 = number of bytes in one row
	# a3 = address of the (0,0) point

main:
	# opening input file

	li $v0, 13		# open file syscall
	la $a0, in_file		# file name
	li $a1, 0		# flag for reading
	li $a2, 0		# mode is ignored
	syscall
	bltz $v0, opening_input_error 	# if file descriptor is negative than error occured
	move $s0, $v0		# saving input file descriptor to s0
	
	# reading from input file
	
	# reading File header and Image header size
	
	li $v0, 14		# read from file syscall
	move $a0, $s0		# first argument is file descriptor
	la $a1, data_holder	# second argument if buffer address
	li $a2, 18		# third argument is number of characters to read
	syscall 
	blez $v0, reading_from_input_error
	
	# reading image width
	li $v0, 14
	la $a1, data_holder
	li $a2, 4
	syscall
	blez $v0, reading_from_input_error
	
	# saving image width to s1
	la $t0, data_holder
	lw $s1, ($t0)
	
		
	# reading image height
	li $v0, 14
	la $a1, data_holder
	li $a2, 4
	syscall
	blez $v0, reading_from_input_error
	
	# saving image height to s2
	la $t0, data_holder
	lw $s2, ($t0)
	
	# reading number of color planes, bits per pixel, compression
	li $v0, 14
	la $a1, data_holder
	li $a2, 8
	syscall
	blez $v0, reading_from_input_error
	
	# reading actual pixel array size
	li $v0, 14
	la $a1, data_holder
	li $a2, 4
	syscall
	blez $v0, reading_from_input_error
	
	# saving pixel array size to s3
	la $t0, data_holder
	lw $s3, ($t0)
	

	# closing input file
	
	li $v0, 16
	syscall
	
	# calculating padding
	
	mulu $t0, $s1, 0x03		# tmp = width * 3 bytes per pixel
	andi $t0, $t0, 0x03		# tmp mod 4
	move $s4, $zero			# setting register containing padding value to 0
	beqz $t0, input			# it will remain 0 if modulo operation returned this value
	li $t1, 4			# tmp2 = 4
	subu $s4, $t1, $t0		# padding = 4 - tmp
	
	
	
	# Values of coordinates beetween -128 and 128 are justified. 10 bits of a register are reserved for fraction part.
	# When fraction is squared, it will require 20 bits not to lose the accuracy. 128 is 2^7. Multiplied by a number
	# slightly smaller than 2^20 will give us a decimal that can be written down on 27 bits. Program does shifting twice.
	# First it shifts 6 times to the right so 21 lower bits will be occupied. This leaves upper 10 bits free (1 is for
	# sign bit as it is U2 system) which can store a number up to 1023 which is a suggested upper bound of width of
	# the image.
	

	
input:	
	# Taking coordinates of 3 points from user
	# They will be stored in t2 - t7 registers

	li $v0, 4
	la $a0, prompt
	syscall
	
point_0:

	# Asking for the first point coordinates
	li $v0, 4
	la $a0, first_point_prompt
	syscall
	
	#reading x coordinate of the first point
	li $v0, 5		# read int syscall
	syscall
	move $t2, $v0		# storing it in t2
	blt $t2, -128, point_0
	bgt $t2, 128, point_0
	
	#reading y coordinate of the first point
	li $v0, 5
	syscall
	move $t3, $v0
	blt $t3, -128, point_0
	bgt $t3, 128, point_0
	
point_1:
	# Asking for the second point coordinates
	li $v0, 4
	la $a0, second_point_prompt
	syscall

	#reading x coordinate of the secont point
	li $v0, 5
	syscall
	move $t4, $v0
	blt $t4, -128, point_1
	bgt $t4, 128, point_1
	
	#reading y coordinate of the second point
	li $v0, 5
	syscall
	move $t5, $v0
	blt $t5, -128, point_1
	bgt $t5, 128, point_1
	
point_2:
	# Asking for the third point coordinates
	li $v0, 4
	la $a0, third_point_prompt
	syscall

	#reading x coordinate of the third point
	li $v0, 5
	syscall
	move $t6, $v0
	blt $t6, -128, point_2
	bgt $t6, 128, point_2
	
	#reading y coordinate of third point
	li $v0, 5
	syscall
	move $t7, $v0
	blt $t7, -128, point_2
	bgt $t7, 128, point_2
	
	
	# allocating memory on heap for bitmap data
	
	li $v0, 9		# sbrk syscall
	move $a0, $s3		# how much memory to allocate (size of pixel array is in s3 register)
	syscall
	move $s5, $v0		# saving allocated memory address to s5
	
	
	# loading pixel array into allocated memory
	
	#opening input file
	li $v0, 13
	la $a0, in_file
	li $a1, 0
	li $a2, 0
	syscall
	bltz $v0, opening_input_error
	move $s0, $v0
	
	# reading file header and DIB header
	li $v0, 14
	move $a0, $s0
	la $a1, header
	li $a2, 54
	syscall
	blez $v0, reading_from_input_error
	
	# reading data
	li $v0, 14
	move $a1, $s5		# address of allocated memory
	move $a2, $s3		# pixel array size
	syscall
	blez $v0, reading_from_input_error
	
	# closing input file
	li $v0, 16
	syscall
	

	# Printing X axis
	
	srl $t0, $s2, 0x01	# t0 = height / 2
	move $t1, $s1		# t1 = width, iterator
	mulu $t8, $t1, 0x03	# t8 = width * 3 bytes per pixel
	addu $t8, $t8, $s4	# t8 = t8 + padding (size of one row in bytes)
	mulu $t0, $t0, $t8	# t0 = t0 * t8; h/2 * (width + padd.) (offset to the first byte of the middle row)
	addu $t0, $s5, $t0	# adding this offset to the memory address to get its address
	
loopX:
	
	sb $zero, ($t0)
	sb $zero, 1($t0)
	sb $zero, 2($t0)		# storing one pixel
	addiu $t0, $t0, 0x03	# address += 3
	subu $t1, $t1, 0x01		# iterator -= 1
	bnez $t1, loopX		# loop if iterator != 0
	
	
	# Printing Y axis
	
	move $t0, $s2		# t0 = height, iterator
	srl $t1, $s1, 0x01	# t1 = width / 2
	mulu $t1, $t1, 0x03	# t1 = widht / 2 * 3 bytes per pixel; offset to the middle byte of the first row
	addu $t1, $s5, $t1	# t1 = address of this bit; memory address + offset
	mulu $t8, $s1, 0x03	# t8 = width * 3 bytes per pixel
	addu $t8, $t8, $s4	# t8 = t8 + padding; number of bytes in one row
	
loopY:
	
	sb $zero, ($t1)
	sb $zero, 1($t1)
	sb $zero, 2($t1)		# storing one pixel
	addu $t1, $t1, $t8	# address += t8 (address + number of bytes in one row)
	subu $t0, $t0, 0x01		# iterator -= 1
	bnez $t0, loopY		# loop if iterator != 0
	
	
	
	
	
	# Calculations
	# B(t) = (1-t)^2 * P0 + 2 * t * (1-t) * P1 + t^2 * P2
	
	# As t parameter needs to be from range <0 , 1>, and we can't use floating point numbers, we will do all the operations
	# on decimals. Program will use the convension that last ten bits are reserved for fraction, thus the smallest value of
	# t parameter we can oparate on is 1 and the biggest is 2^10 - 1. Since we need decimal value of the pixel's position
	# anyway, we will just do arithmetic shift to the right on the result.
	
	move $t8, $zero		# t8 = our t parameter
	li $t9, 0x3ff		# t9 1-t; iteraotr; 2^10 - 1
	
	# we will also calculate the address of the (0,0) point. It will really help in further addresses calculations
	
	srl $a0, $s1, 0x01	# a0 = width / 2
	mul $a0, $a0, 0x03	# a0 = width / 2 * 3 bytes per pixel
	srl $a1, $s2, 0x01	# a1 = height / 2
	mul $a2, $s1, 0x03	# a2 = width * 3 bytes per pixel
	addu $a2, $a2, $s4	# a2 = width * 3 bytes per pixel + padding; number of bytes in one row
	mul $a1, $a1, $a2	# a1 = height / 2 * bytes in one row; offset to the middle row
	addu $a1, $a1, $a0	# a1 = offset to the middle byte of the middle row
	addu $a3, $s5, $a1	# a3 = allocated memory address + offset; a3 is the address of (0,0) point
	
next_point:
	
	# Calculating x and y coordinates of the point
	
	mul $a0, $t9, $t9	# a0 = (1-t)^2
	mul $t0, $a0, $t2	# t0 = (1-t)^2 * P0x
	mul $t1, $a0, $t3	# t1 = (1-t)^2 * P0y
	
	mul $a0, $t8, $t9	# a0 = t * (1-t)
	sll $a0, $a0, 0x01	# a0 = 2 * t * (1-t)
	mul $a1, $a0, $t4	# a1 = 2 * t * (1-t) * P1x
	add $t0, $t0, $a1	# t0 = (1-t)^2 * P0x + 2 * t * (1-t) * P1x
	mul $a1, $a0, $t5	# a1 = 2 * t * (1-t) * P1y
	add $t1, $t1, $a1	# t1 = (1-t)^2 * P0y + 2 * t * (1-t) * P1y
	
	mul $a0, $t8, $t8	# a0 = t^2
	mul $a1, $a0, $t6	# a1 = t^2 * P2x
	add $t0, $t0, $a1	# t0 = (1-t)^2 * P0x + 2 * t * (1-t) * P1x + t^2 * P2x
	mul $a1, $a0, $t7	# a1 = t^2 * P2y
	add $t1, $t1, $a1	# t1 = (1-t)^2 * P0y + 2 * t * (1-t) * P1y + t^2 * P2y
	
	
	# Since the range of x coordinate is from -32 to 32 and we don't know what the size of loaded image will be
	# we have to use a scale to calculate which pixel we need to paint. It is width / 64 but we can't do that operation
	# because later on we need to multiply it by our point's position to receive the number of pixel and all the accuracy
	# would be lost.
	# The best solution would be multiplying the result by width and since we will be doing right shift
	# anyway, we could just shift more bits at one time. But our t parameter ought to be shifted 20 times because it was
	# squared and then we have 6 more bits to shift for the scale. It leaves only 5 more bits for the actual calculated
	# pixel's number which is far too little than we need. That is why this program will do the smaller shift first,
	# then do the multiplication and the bigger shift in the end.
	
	# This provides both quite good accuracy and ability to operate on bigger files with the actual line drawn in the file
	# and not just few points.
	
	
	
	sra $t0, $t0, 0x06	# dividing both coordinates by 64 which is our default image width
	sra $t1, $t1, 0x06

	
	mul $t0, $t0, $s1	# multiply by image width; scale of the image is implied to the result
	mul $t1, $t1, $s1
	
	
	# removing the fraction part of the number; shifting 20 times to the right
	
	sra $t0, $t0, 0x14
	sra $t1, $t1, 0x14

calculate_address:


	# if pixel's calculated position won't match any pixel array point it won't be printed so we don't have to calculate
	# the address
	
	srl $a0, $s1, 0x01		# a0 = width / 2
	bgt $t0, $a0, iter		# if x > width / 2 we won't do the painting
	sub $a0, $zero, $a0		# a0 = -width / 2
	blt $t0, $a0, iter		# if x < -width / 2
	
	srl $a0, $s2, 0x01
	bgt $t1, $a0, iter
	sub $a0, $zero, $a0
	blt $t1, $a0, iter



	
	# Calculating address of the pixel above
	
	mul $a0, $t1, $a2	# a0 = y * num of bytes in one row; offset from (0,0) to the middle of the row given by y
	add $a0, $a3, $a0	# a0 = address of the middle point in the row given by y coordinate
	mul $a1, $t0, 0x03	# a1 = x * 3 bytes per pixel; offset from the middle of a row to x coordinate
	add $a0, $a0, $a1	# a0 = address of the pixel we've looked for
	
	sb $zero, ($a0)
	sb $zero, 1($a0)
	sb $zero, 2($a0)

iter:
	
	addi $t8, $t8, 0x01	# t parameter += 1
	subi $t9, $t9, 0x01	# iterator -= 1
	bne $t9, -0x01, next_point
	
	
	
	# clearing used registers
	move $a0, $zero
	move $a1, $zero
	move $a2, $zero
	move $a3, $zero
	
	
	
	# saving our data to output file
	
	# opening
	li $v0, 13
	la $a0, out_file	# name
	li $a1, 1		# writing flag
	li $a2, 0		# mode is ignored
	syscall
	bltz $v0, opening_output_error
	move $s6, $v0		# saving output file descriptor to s6
	
	# storing file header
	li $v0, 15		# syscall for writing to file
	move $a0, $s6		# moving output file descriptor to a0
	la $a1, header		# loading address of the header
	li $a2, 54		# how much bytes to store
	syscall
	blez $v0, storing_to_output_error
	
	# storing pixel array
	li $v0, 15
	move $a1, $s5		# memory address of processed data
	move $a2, $s3		# size of the memory
	syscall
	blez $v0, storing_to_output_error
	
	
	# closing output file
	li $v0, 16
	move $a0, $s6
	syscall
	
	
exit:
	li $v0, 10
 	syscall
	

opening_input_error:
	li $v0, 4
	la $a0, open_in_file_err
	syscall
	j exit
	
reading_from_input_error:
	# closing input file
	li $v0, 16
	move $a0, $s0
	syscall
	li $v0, 4
	la $a0, read_from_in_file_err
	syscall
	j exit
opening_output_error:
	li $v0, 4
	la $a0, open_out_file_err
	syscall
	j exit

storing_to_output_error:
	# closing output file
	li $v0, 16
	move $a0, $s6
	syscall
	li $v0, 4
	la $a0, store_to_out_file_err
	syscall
	j exit
