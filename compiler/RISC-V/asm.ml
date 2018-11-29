type id_or_imm = (* V = variable, C = constant *)
  | V of Id.t
  | C of int
type p = Lexing.position * Lexing.position
type t = (* 命令の列 *)
  | Ans of exp
  | Let of (Id.t * Type.t) * exp * t
and exp = (* 命令（仮想命令含む） *)
  | Nop of p
  | Li of int * p
  | LiL of Id.l * p
  | Mv of Id.t * p
  | Neg of Id.t * p
  | Add of Id.t * id_or_imm * p
  | Sub of Id.t * id_or_imm * p
  | Mul of Id.t * id_or_imm * p
  | Div of Id.t * id_or_imm * p
  | SLL of Id.t * id_or_imm * p
  | SRL of Id.t * id_or_imm * p
  | Lw of Id.t * id_or_imm * p
  | Sw of Id.t * Id.t * id_or_imm * p (* Sw(x, y, z') means M[x + z'] <- y *)
  | FMv of Id.t * p
  | FAbs of Id.t * p
  | FNeg of Id.t * p
  | FAdd of Id.t * Id.t * p
  | FSub of Id.t * Id.t * p
  | FMul of Id.t * Id.t * p
  | FDiv of Id.t * Id.t * p
  | FLw of Id.t * id_or_imm * p
  | FSw of Id.t * Id.t * id_or_imm * p (* FSw(x, y, z') means M[x + z'] <- y *)
  (* virtual instructions *)
  | IfEq of Id.t * Id.t * t * t * p
  | IfLE of Id.t * Id.t * t * t * p
  | IfFEq of Id.t * Id.t * t * t * p
  | IfFLE of Id.t * Id.t * t * t * p
  (* closure address, integer arguments, and float arguments *)
  | CallCls of Id.t * Id.t list * Id.t list * p
  | CallDir of Id.l * Id.t list * Id.t list * p
  (* Save(r, y) = レジスタrに入っている変数yをスタックに退避 *)
  | Save of Id.t * Id.t * p
  | Restore of Id.t * p (* スタックから値を戻す *)
type fundef =
  { name : Id.l; args : Id.t list; fargs : Id.t list;
    body : t; ret : Type.t }
(* プログラム = (float_table, 関数リスト, 命令列) *)
type prog = Prog of (Id.l * float) list * fundef list * t

let dp = (Lexing.dummy_pos, Lexing.dummy_pos)

let fletd(x, e1, e2) = Let((x, Type.Float), e1, e2)
let seq(e1, e2) = Let((Id.gentmp Type.Unit, Type.Unit), e1, e2)

(* 自由レジスタ集 *)
(* 引数レジスタはこれの先頭から割り当てられていくっぽい *)
(* TODO:個数とか変える *)
(* 先頭4つだけ正しくした *)
(* TODO:caller-saveとcallee-save *)
(* 今は多分全部saveする仕様 *)
(* TODO:regsを直接見ている悪いやつをどうにかする *)
let regs = Array.init 22 (fun i -> Printf.sprintf "a%d" i)
let regs_tmp = Array.init 5 (fun i -> Printf.sprintf "t%d" i)
let fregs = Array.init 27 (fun i -> Printf.sprintf "fa%d" i)
let fregs_tmp = Array.init 5 (fun i -> Printf.sprintf "ft%d" i)
let allregs = Array.to_list regs
let allfregs = Array.to_list fregs
(* TODO:こいつら退避不要ならそれを反映させていいのでは？とりあえずaの末端のまま *)
let reg_cl = regs.(Array.length regs - 1) (* closure address用のtmp *)
let reg_sw = regs.(Array.length regs - 2) (* swap用のtmp *)
let reg_fsw = fregs.(Array.length fregs - 1)
let reg_ra = "ra" (* return address *)
let reg_sp = "sp" (* stack pointer *)
let reg_hp = "hp" (* heap pointer *)
let is_reg x =
  List.exists (fun el -> el = x) allregs
  || List.exists (fun el -> el = x) allfregs
  || x = reg_ra || x = reg_sp || x = reg_hp
(* let co_freg_table =
  let ht = Hashtbl.create 16 in
  for i = 0 to 15 do
    Hashtbl.add
      ht
      (Printf.sprintf "%%f%d" (i * 2))
      (Printf.sprintf "%%f%d" (i * 2 + 1))
  done;
  ht
let co_freg freg = Hashtbl.find co_freg_table freg (* "companion" freg *) *)

(* super-tenuki *)
let rec remove_and_uniq xs = function
  | [] -> []
  | x :: ys when S.mem x xs -> remove_and_uniq xs ys
  | x :: ys -> x :: remove_and_uniq (S.add x xs) ys

(* free variables in the order of use (for spilling) *)
let fv_id_or_imm = function V(x) -> [x] | C(_) -> []
let rec fv_exp = function
  | Nop(_) | Li(_) | LiL(_) | Restore(_) -> []
  | Mv(x, _) | Neg(x, _) | FMv(x, _) | FAbs(x, _) | FNeg(x, _)
  | Save(x, _, _) -> [x]
  | Add(x, y', _) | Sub(x, y', _) | Mul(x, y', _) | Div(x, y', _)
  | SLL(x, y', _) | SRL(x, y', _) | Lw(x, y', _) | FLw(x, y', _) ->
      x :: fv_id_or_imm y'
  | Sw(x, y, z', _) | FSw(x, y, z', _) -> x :: y :: fv_id_or_imm z'
  | FAdd(x, y, _) | FSub(x, y, _) | FMul(x, y, _) | FDiv(x, y, _) -> [x; y]
  | IfEq(x, y, e1, e2, _) | IfLE(x, y, e1, e2, _) ->
      x :: y :: remove_and_uniq S.empty (fv e1 @ fv e2)
  | IfFEq(x, y, e1, e2, _) | IfFLE(x, y, e1, e2, _) ->
      x :: y :: remove_and_uniq S.empty (fv e1 @ fv e2)
  | CallCls(x, ys, zs, _) -> x :: ys @ zs
  | CallDir(_, ys, zs, _) -> ys @ zs
and fv = function
  | Ans(exp) -> fv_exp exp
  | Let((x, t), exp, e) ->
      fv_exp exp @ remove_and_uniq (S.singleton x) (fv e)
let fv e = remove_and_uniq S.empty (fv e)

(*
e1 : Asm.t
xt : Id.t * Type.t
e2 : Asm.t
let x = e1 in e2 への変換
e1がlet式だった場合はe1内のlet定義を頭出しする
つまりe1が let y = exp in e1' なら let y = exp in (let x = e1' in e2)になる
*)
let rec concat e1 xt e2 =
  match e1 with
  | Ans(exp) -> Let(xt, exp, e2)
  | Let(yt, exp, e1') -> Let(yt, exp, concat e1' xt e2)

let align i = i (* (if i mod 8 = 0 then i else i + 4) *)
