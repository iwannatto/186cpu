	j	min_caml_start
fibonacci.11:
	li	a1, 0 ! 2
	bne	a0, a1, be_else.26
	li	a0, 0 ! 2
	ret ! 2
be_else.26:
	li	a1, 1 ! 3
	bne	a0, a1, be_else.27
	li	a0, 1 ! 3
	ret ! 3
be_else.27:
	addi	a1, a0, -1 ! 4
	sw	sp, a0, 0 ! 0
	mv	a0, a1
	sw	sp, ra, 4
	addi	sp, sp, 8
	jal	fibonacci.11
	addi	sp, sp, -8
	lw	ra, sp, 4
	lw	a1, sp, 0 ! 0
	addi	a1, a1, -2 ! 4
	sw	sp, a0, 4 ! 0
	mv	a0, a1
	sw	sp, ra, 12
	addi	sp, sp, 16
	jal	fibonacci.11
	addi	sp, sp, -16
	lw	ra, sp, 12
	lw	a1, sp, 4 ! 0
	add	a0, a1, a0 ! 4
	ret ! 4
min_caml_start:
	li	a0, 6 ! 5
	sw	sp, ra, 4
	addi	sp, sp, 8
	jal	fibonacci.11
	addi	sp, sp, -8
	lw	ra, sp, 4
	sw	sp, ra, 4
	addi	sp, sp, 8
	jal	min_caml_print_int
	addi	sp, sp, -8
	lw	ra, sp, 4
	fin	0