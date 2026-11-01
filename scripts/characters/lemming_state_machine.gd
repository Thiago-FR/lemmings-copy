class_name LemmingStateMachine
extends RefCounted
## Owns the lemming's current state and notifies listeners on transitions.
## Movement/physics logic stays in LemmingController; skill behavior stays
## in the individual skill scripts (skills/skill_base.gd subclasses).

enum State {
	FALLING,
	WALKING,
	DIGGING,
	BUILDING,
	BLOCKING,
	BASHING,
	MINING,
	CLIMBING,
	FLOATING,
	LADDER_PLACING,
	LADDER_CLIMBING,
	EXPLODING,
	DEAD,
	EXITED,
}

signal state_changed(previous_state: State, new_state: State)

var current_state: State = State.FALLING


func change_state(new_state: State) -> void:
	if new_state == current_state:
		return
	var previous_state := current_state
	current_state = new_state
	state_changed.emit(previous_state, new_state)


func is_alive() -> bool:
	return current_state != State.DEAD and current_state != State.EXITED


## States a skill can normally be assigned from (excludes DEAD/EXITED and
## states already governed by another active skill).
func can_receive_skill() -> bool:
	return current_state == State.WALKING or current_state == State.FALLING
