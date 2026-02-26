import EvmYul.EVM.Semantics

open EvmYul
open EVM

namespace Lean424Harness

structure Snapshot where
  op : String
  ok : Bool
  pc : Nat
  gasAvailable : Nat
  stackLen : Nat
  stackTop : Nat
  activeWords : Nat
  refundBalance : Nat
  deriving Repr

def mkBaseState : EVM.State :=
  { default with
    gasAvailable := UInt256.ofNat 1000000
    pc := .ofNat 0
    returnData := ByteArray.empty
    execLength := 0
  }

def withStack (xs : List Nat) : EVM.State :=
  { mkBaseState with
    stack := xs.map UInt256.ofNat
  }

def stackTopNat (st : EVM.State) : Nat :=
  match st.stack with
  | [] => 0
  | x :: _ => x.toNat

def toSnapshot (name : String) (res : Except EVM.Exception EVM.State) : Snapshot :=
  match res with
  | .ok st =>
    { op := name
      ok := true
      pc := st.pc.toNat
      gasAvailable := st.gasAvailable.toNat
      stackLen := st.stack.length
      stackTop := stackTopNat st
      activeWords := st.activeWords.toNat
      refundBalance := st.substate.refundBalance.toNat
    }
  | .error _ =>
    { op := name
      ok := false
      pc := 0
      gasAvailable := 0
      stackLen := 0
      stackTop := 0
      activeWords := 0
      refundBalance := 0
    }

def runOp (name : String) (op : Operation .EVM) (st : EVM.State) : Snapshot :=
  toSnapshot name (EVM.step 1 50000 (some ⟨op, none⟩) st)

def snapshots : List Snapshot :=
  [ runOp "STOP" (@Operation.STOP .EVM) mkBaseState
    runOp "PUSH0" (@Operation.PUSH0 .EVM) mkBaseState
    runOp "MLOAD" (@Operation.MLOAD .EVM) (withStack [0])
    runOp "MSTORE" (@Operation.MSTORE .EVM) (withStack [0, 7])
    runOp "MSTORE8" (@Operation.MSTORE8 .EVM) (withStack [0, 255])
    runOp "SLOAD" (@Operation.SLOAD .EVM) (withStack [1])
    runOp "SSTORE" (@Operation.SSTORE .EVM) (withStack [1, 9])
    runOp "EXP" (@Operation.EXP .EVM) (withStack [2, 10])
    runOp "ONEOP.ISZERO" (@Operation.ISZERO .EVM) (withStack [0])
    runOp "TWOOP.ADD" (@Operation.ADD .EVM) (withStack [2, 3])
  ]

def render (s : Snapshot) : String :=
  s!"{s.op}|ok={s.ok}|pc={s.pc}|gas={s.gasAvailable}|stackLen={s.stackLen}|top={s.stackTop}|activeWords={s.activeWords}|refund={s.refundBalance}"

def main : IO Unit := do
  for s in snapshots do
    IO.println (render s)

end Lean424Harness
