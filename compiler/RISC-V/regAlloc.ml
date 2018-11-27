open Asm

let rec target' src (dest, t) (inst, pos) =
  match inst with
  | Mov(x) when x = src && is_reg dest ->
      assert (t <> Type.Unit);
      assert (t <> Type.Float);
      false, [dest]
  | FMv(x) when x = src && is_reg dest ->
      assert (t = Type.Float);
      false, [dest]
  | IfEq(_, _, e1, e2) | IfLE(_, _, e1, e2)
  | IfFEq(_, _, e1, e2) | IfFLE(_, _, e1, e2) ->
  (* | IfGE(_, _, e1, e2) *)
      let c1, rs1 = target src (dest, t) e1 in
      let c2, rs2 = target src (dest, t) e2 in
      c1 && c2, rs1 @ rs2
  | CallCls(x, ys, zs) ->
      true, (target_args src regs 0 ys @
             target_args src fregs 0 zs @
             if x = src then [reg_cl] else [])
  | CallDir(_, ys, zs) ->
      true, (target_args src regs 0 ys @
             target_args src fregs 0 zs)
  | _ -> false, []
and target src dest = function
  | Ans(inst) -> target' src dest inst
  | Let(xt, inst, e) ->
      let c1, rs1 = target' src xt inst in
      if c1 then true, rs1 else
      let c2, rs2 = target src dest e in
      c2, rs1 @ rs2
and target_args src all n = function (* auxiliary function for Call *)
  | [] -> []
  | y :: ys when src = y -> all.(n) :: target_args src all (n + 1) ys
  | _ :: ys -> target_args src all (n + 1) ys

(*
Alloc(r)はレジスタrに割り当てることができたという意味
Spill(y)はレジスタ割り当てできなかったのでいま定義されている変数yを逃がしましょうという意味
 *)
type alloc_result =
  | Alloc of Id.t
  | Spill of Id.t
let rec alloc dest cont regenv x t =
  assert (not (M.mem x regenv));
  let all =
    match t with
    | Type.Unit -> ["zero"] (* dummy *)
    | Type.Float -> allfregs
    | _ -> allregs in
  if all = ["zero"] then Alloc("zero") else
  if is_reg x then Alloc(x) else
  let free = fv cont in
  try
    let (c, prefer) = target x dest cont in
    let live =
      List.fold_left
        (fun live y ->
          if is_reg y then S.add y live else
          try S.add (M.find y regenv) live
          with Not_found -> live)
        S.empty
        free in
    let r =
      List.find
        (fun r -> not (S.mem r live))
        (prefer @ all) in
    (* Format.eprintf "allocated %s to %s@." x r; *)
    Alloc(r)
  with Not_found ->
    Format.eprintf "register allocation failed for %s@." x;
    (* レジスタに割り当てられている変数yを型が合うレジスタの中から探す *)
    let f y = not (is_reg y)
              && try List.mem (M.find y regenv) all with Not_found -> false in
    (* 自由変数（＝いま定義されているので逃がす意味がある変数）の中からyを探す *)
    let y = List.find f (List.rev free) in
    Format.eprintf "spilling %s from %s@." y (M.find y regenv);
    Spill(y)

(* auxiliary function for g and g'_and_restore *)
let add x r regenv =
  if is_reg x then (assert (x = r); regenv) else
  M.add x r regenv

(* auxiliary functions for g' *)
exception NoReg of Id.t * Type.t
let find x t regenv =
  if is_reg x then x else
  try M.find x regenv
  with Not_found -> raise (NoReg(x, t))
let find' x' regenv =
  match x' with
  | V(x) -> V(find x Type.Int regenv)
  | c -> c

(*
dest : Id.t * Type.t -> cont : Asm.t -> regenv : ? M.t -> Asm.t
-> Asm.t * ? M.t
Asm.t(命令列)に対するレジスタ割り当て
*)
let rec g dest cont regenv = function
  | Ans(exp) -> g'_and_restore dest cont regenv exp
  (* let x = exp in e の変数xに割り当てをする *)
  | Let((x, t) as xt, exp, e) ->
      assert (not (M.mem x regenv)); (* k正規化済、既に割り当てられているはずはない *)
      let cont' = concat e dest cont in (* eを後ろに回す *)
      (* exp内の変数は今のregenvに収まるはずなので、regenvを適用しておく *)
      let (e1', regenv1) = g'_and_restore xt cont' regenv exp in
      (* xのぶんのレジスタが余っているか判定 *)
      (match alloc dest cont' regenv1 x t with
      | Spill(y) -> (* ダメだったら変数yを退避する *)
          let r = M.find y regenv1 in (* いまyが入っているレジスタ *)
          (* xをrに入れてyを潰してしまい、その状態で割り当てをする *)
          let (e2', regenv2) = g dest cont (add x r (M.remove y regenv1)) e in
          (* yのsaveを発行する *)
          let save =
            try (Save(M.find y regenv, y), Lexing.dummy_pos)
            (* ここに来る条件はわからない *)
            with Not_found -> (Nop, Lexing.dummy_pos) in
          (seq(save, concat e1' (r, t) e2'), regenv2)
      | Alloc(r) -> (* レジスタrが見つかったら素直にxをrに入れる *)
          let (e2', regenv2) = g dest cont (add x r regenv1) e in
          (concat e1' (r, t) e2', regenv2))
(* g'を実行しつつ、レジスタが（saveされていて）見つからなかった場合はrestoreを挟む *)
and g'_and_restore dest cont regenv exp =
  try g' dest cont regenv exp
  with NoReg(x, t) ->
    g dest cont regenv (Let((x, t), (Restore(x), Lexing.dummy_pos), Ans(exp)))
(*
Asm.expに対するレジスタ割り当て
regenvとして変数名→レジスタの対応があるので、それを適用するというだけ
*)
(* TODO:分岐の際に必ずnopが発生しているがこれはいらない（emitかもしれない） *)
(* TODO:即値ifに関するものは消していい *)
and g' dest cont regenv (inst, sp) =
  match inst with
  | Nop | Set _ | SetL _ | Restore _ -> (Ans(inst, sp), regenv)
  | Mov(x) -> (Ans(Mov(find x Type.Int regenv), sp), regenv)
  | Neg(x) -> (Ans(Neg(find x Type.Int regenv), sp), regenv)
  | Add(x, y') ->
      (Ans(Add(find x Type.Int regenv, find' y' regenv), sp), regenv)
  | Sub(x, y') ->
      (Ans(Sub(find x Type.Int regenv, find' y' regenv), sp), regenv)
  | Mul(x, y') ->
      (Ans(Mul(find x Type.Int regenv, find' y' regenv), sp), regenv)
  | Div(x, y') ->
      (Ans(Div(find x Type.Int regenv, find' y' regenv), sp), regenv)
  | SLL(x, y') ->
      (Ans(SLL(find x Type.Int regenv, find' y' regenv), sp), regenv)
  | SRL(x, y') ->
      (Ans(SRL(find x Type.Int regenv, find' y' regenv), sp), regenv)
  | Ld(x, y') ->
      (Ans(Ld(find x Type.Int regenv, find' y' regenv), sp), regenv)
  | St(x, y, z') ->
      (Ans(St(find x Type.Int regenv,
              find y Type.Int regenv,
              find' z' regenv), sp), regenv)
  | FMv(x) -> (Ans(FMv(find x Type.Float regenv), sp), regenv)
  | FNeg(x) -> (Ans(FNeg(find x Type.Float regenv), sp), regenv)
  | FAdd(x, y) ->
    (Ans(FAdd(find x Type.Float regenv, find y Type.Float regenv), sp), regenv)
  | FSub(x, y) ->
    (Ans(FSub(find x Type.Float regenv, find y Type.Float regenv), sp), regenv)
  | FMul(x, y) ->
    (Ans(FMul(find x Type.Float regenv, find y Type.Float regenv), sp), regenv)
  | FDiv(x, y) ->
    (Ans(FDiv(find x Type.Float regenv, find y Type.Float regenv), sp), regenv)
  | LdDF(x, y') ->
      (Ans(LdDF(find x Type.Int regenv, find' y' regenv), sp), regenv)
  | StDF(x, y, z') ->
      (Ans(StDF(find x Type.Float regenv,
                find y Type.Int regenv,
                find' z' regenv), sp), regenv)
  (* y'が即値である可能性がなくなったので、そこを削除 *)
  | IfEq(x, y, e1, e2) as inst ->
      let constr e1' e2' =
        IfEq(find x Type.Int regenv, find y Type.Int regenv, e1', e2') in
      g'_if dest cont regenv inst constr e1 e2
  | IfLE(x, y, e1, e2) as inst ->
      let constr e1' e2' =
        IfLE(find x Type.Int regenv, find y Type.Int regenv, e1', e2') in
      g'_if dest cont regenv inst constr e1 e2
  (* | IfGE(x, y, e1, e2) as inst ->
      let constr e1' e2' =
        IfGE(find x Type.Int regenv, find y Type.Int regenv, e1', e2') in
      g'_if dest cont regenv inst constr e1 e2 *)
  | IfFEq(x, y, e1, e2) as inst ->
      let constr e1' e2' =
        IfFEq(find x Type.Float regenv, find y Type.Float regenv, e1', e2') in
      g'_if dest cont regenv inst constr e1 e2
  | IfFLE(x, y, e1, e2) as inst ->
      let constr e1' e2' =
        IfFLE(find x Type.Float regenv, find y Type.Float regenv, e1', e2') in
      g'_if dest cont regenv inst constr e1 e2
  | CallCls(x, ys, zs) as inst ->
      if List.length ys > Array.length regs - 2 || List.length zs > Array.length fregs - 1 then
        failwith (Format.sprintf
                    "cannot allocate registers for arugments to %s"
                    x)
      else
        g'_call
          dest
          cont
          regenv
          inst
          (fun ys zs -> CallCls(find x Type.Int regenv, ys, zs))
          ys
          zs
  | CallDir(Id.L(x), ys, zs) as inst ->
      if List.length ys > Array.length regs - 1 || List.length zs > Array.length fregs - 1 then
        failwith
          (Format.sprintf "cannot allocate registers for arugments to %s" x)
      else
        g'_call dest cont regenv inst (fun ys zs -> CallDir(Id.L(x), ys, zs)) ys zs
  | Save(x, y) -> assert false
(* ifにレジスタを割り当てる *)
(* inst捨ててる？ *)
and g'_if dest cont regenv inst constr e1 e2 =
  (* 分岐先2つにレジスタを割り当てる *)
  let (e1', regenv1) = g dest cont regenv e1 in
  let (e2', regenv2) = g dest cont regenv e2 in
  (* contの中から、分岐先両方に出てくるレジスタのみを抽出する *)
  let regenv' =
    List.fold_left
      (fun regenv' x ->
        try
          if is_reg x then regenv' else
          let r1 = M.find x regenv1 in
          let r2 = M.find x regenv2 in
          if r1 <> r2 then regenv' else
          M.add x r1 regenv'
        with Not_found -> regenv')
      M.empty
      (fv cont) in
  (* 共通していない変数は退避する *)
  (List.fold_left
     (fun insts x ->
       if x = fst dest || not (M.mem x regenv) || M.mem x regenv' then
         insts
       else
         seq((Save(M.find x regenv, x), Lexing.dummy_pos), insts))
     (Ans(constr e1' e2', Lexing.dummy_pos))
     (fv cont),
   regenv')
(* inst捨ててる？ *)
and g'_call dest cont regenv inst constr ys zs =
  ((List.fold_left
     (fun e x ->
       (* dest使っているところ *)
       (* 関数呼出しとかの移動先のことか？ *)
       if x = fst dest || not (M.mem x regenv) then e else
       seq((Save(M.find x regenv, x), Lexing.dummy_pos), e))
    (Ans((constr
            (List.map (fun y -> find y Type.Int regenv) ys)
            (List.map (fun z -> find z Type.Float regenv) zs)),
          Lexing.dummy_pos))
     (fv cont)),
   M.empty)

(* 関数→レジスタ割り当てされた関数 *)
let h { name = Id.L(x); args = ys; fargs = zs; body = insts; ret = t } =
  (* regenv(Id.tとstring(レジスタ)を対応させたM)を大きくしていく *)
  (* 関数名とreg_clとの対応を追加 *)
  let regenv = M.add x reg_cl M.empty in
  (* 整数引数とレジスタとの対応を追加 *)
  let (i, arg_regs, regenv) =
    List.fold_left
      (fun (i, arg_regs, regenv) y ->
        (* 自由レジスタの先頭から取っていく *)
        let r = regs.(i) in
        (i + 1,
         arg_regs @ [r],
         (assert (not (is_reg y)); (* なんのassertかわからん *)
          M.add y r regenv)))
      (0, [], regenv)
      ys in
  (* 浮動小数点数引数とレジスタとの対応を追加 *)
  let (d, farg_regs, regenv) =
    List.fold_left
      (fun (d, farg_regs, regenv) z ->
        let fr = fregs.(d) in
        (d + 1,
         farg_regs @ [fr],
         (assert (not (is_reg z)); (* なんのassertかわからん *)
          M.add z fr regenv)))
      (0, [], regenv)
      zs in
  (* 返り値レジスタ *)
  let a =
    match t with
    | Type.Unit -> Id.gentmp Type.Unit
    | Type.Float -> fregs.(0)
    | _ -> regs.(0) in
  let (insts', regenv') = g (a, t) (Ans(Mov(a), Lexing.dummy_pos)) regenv insts in
  { name = Id.L(x); args = arg_regs; fargs = farg_regs;
    body = insts'; ret = t }

(* プログラム→レジスタ割り当てされたプログラム *)
let f (Prog(float_table, fundefs, insts)) =
  Format.eprintf "register allocation: may take some time (up to a few minutes, depending on the size of functions)@.";
  (* 関数定義にレジスタを割り当てる *)
  let fundefs' = List.map h fundefs in
  (* 命令列にレジスタを割り当てる *)
  let insts', regenv' =
    g (Id.gentmp Type.Unit, Type.Unit) (Ans(Nop, Lexing.dummy_pos)) M.empty insts in
  Prog(float_table, fundefs', insts')
