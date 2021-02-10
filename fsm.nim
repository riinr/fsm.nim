import tables, strutils, options

type
  Callback = proc(): void
  StateEvent[State, Event] = tuple[state: State, event: Event]
  Transition[State] = tuple[nexState: State, action: Option[Callback]]

  Machine[State, Event] =  ref object of RootObj
    initialState: State
    currentState: Option[State]
    transitions: TableRef[StateEvent[State,Event], Transition[State]]
    transitionsAny: TableRef[State, Transition[State]]
    defaultTransition: Option[Transition[State]]

  TransitionNotFoundException = object of ValueError

proc reset*(machine: Machine) =
  machine.currentState = some(machine.initialState)

proc setInitialState*[State, Event](machine: Machine[State, Event], state: State) =
  machine.initialState = state
  if isNone machine.currentState:
    machine.reset()

proc newMachine*[State, Event](initialState: State): Machine[State, Event] =
  result = new(Machine[State, Event])
  result.transitions = newTable[StateEvent[State, Event], Transition[State]]()
  result.transitionsAny = newTable[State, Transition[State]]()
  result.setInitialState(initialState)

proc addTransitionAny*[State, Event](machine: Machine[State, Event], state: State, next: State) =
  machine.transitionsAny[state] = (next, none(Callback))

proc addTransitionAny*[State, Event](machine: Machine[State, Event], state, next: State, action: Callback) =
  machine.transitionsAny[state] = (next, some(action))

proc addTransition*[State, Event](machine: Machine[State,Event], state: State, event: Event, next: State) =
  machine.transitions[(state, event)] = (next, none(Callback))

proc addTransition*[State, Event](machine: Machine[State, Event], state: State, event: Event, next: State, action: Callback) =
  machine.transitions[(state, event)] = (next, some(action))

proc setDefaultTransition*[State, Event](machine: Machine[State, Event], state: State) =
  machine.defaultTransition = some((state, none(Callback)))

proc setDefaultTransition*[State, Event](machine: Machine[State, Event], state: State, action: Callback) =
  machine.defaultTransition = some((state, some(action)))

proc getTransition*[State, Event](machine: Machine[State, Event], event: Event, state: State): Transition[State] =
  let map = (state, event)
  if machine.transitions.hasKey(map):
    result = machine.transitions[map]
  elif machine.transitionsAny.hasKey(state):
    result = machine.transitionsAny[state]
  elif machine.defaultTransition.isSome:
    result = machine.defaultTransition.get
  else: raise newException(TransitionNotFoundException, "Transition is not defined: Event($#) State($#)" % [$event, $state])

proc getCurrentState*(machine: Machine): auto =
  machine.currentState.get

proc process*[State, Event](machine: Machine[State, Event], event: Event) =
  let transition = machine.getTransition(event, machine.currentState.get)
  if transition[1].isSome:
    get(transition[1])()
  machine.currentState = some(transition[0])


when isMainModule:
  proc cb() =
    echo "I'm evaporating"

  type
    State = enum
      SOLID
      LIQUID
      GAS
      PLASMA

    Event = enum
      MELT
      EVAPORATE
      SUBLIMATE
      IONIZE

  var machine = newMachine[State, Event](LIQUID)
  machine.addTransition(SOLID, MELT, LIQUID)
  machine.addTransition(LIQUID, EVAPORATE, GAS, cb)
  machine.addTransition(SOLID, SUBLIMATE, GAS)
  machine.addTransition(GAS, IONIZE, PLASMA)
  machine.addTransition(SOLID, MELT, LIQUID)

  assert machine.getCurrentState() == LIQUID
  machine.process(EVAPORATE)
  assert machine.getCurrentState() == GAS
  machine.process(IONIZE)
  assert machine.getCurrentState() == PLASMA
