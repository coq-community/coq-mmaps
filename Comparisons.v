
From Coq Require Import List.
Import ListNotations.

(** * Some complements on [comparison] *)

Set Implicit Arguments.

(** lexicographic product, defined using a notation to keep things lazy *)

Notation lex u v := match u with Eq => v | Lt => Lt | Gt => Gt end.

Lemma lex_Eq u v : lex u v = Eq <-> u=Eq /\ v=Eq.
Proof. now destruct u. Qed.

(** The comparison function in OrderedType are symmetric and
    transitive in the following sense: *)

Definition Sym {A} (cmp:A->A->comparison) :=
  forall x y, cmp y x = CompOpp (cmp x y).

Definition Trans {A} (cmp:A->A->comparison) :=
  forall c x y z, cmp x y = c -> cmp y z = c -> cmp x z = c.

Class SymTrans {A} (cmp:A->A->comparison) := {
  sym :> Sym cmp;
  tra :> Trans cmp
}.

(** [SymTrans] implies the following compatibility rules *)

Definition CompatR {A} (cmp:A->A->comparison) :=
  forall x y y', cmp y y' = Eq -> cmp x y = cmp x y'.

Definition CompatL {A} (cmp:A->A->comparison) :=
  forall x x' y, cmp x x' = Eq -> cmp x y = cmp x' y.

Ltac flipcmp H :=
 match type of H with ?cmp _ _ = _ =>
   match goal with
   | Sy : Sym cmp |- _ => rewrite Sy, CompOpp_iff in H; simpl in H
   | Sy : SymTrans cmp |- _ => rewrite sym, CompOpp_iff in H; simpl in H
   end
 end.

Lemma SymTrans_CompatR {A} (cmp:A->A->comparison) :
  SymTrans cmp -> CompatR cmp.
Proof.
 intros (Sy,Tr) x y y' Hy.
 destruct (cmp x y) eqn:E, (cmp x y') eqn:E'; trivial.
 - erewrite Tr in E'; eauto.
 - erewrite Tr in E'; eauto.
 - erewrite Tr in E; eauto. now flipcmp Hy.
 - flipcmp E. erewrite Tr in Hy; eauto. easy.
 - flipcmp Hy. erewrite Tr in E; eauto.
 - flipcmp E. erewrite Tr in Hy; eauto. easy.
Qed.

Lemma SymTrans_CompatL {A} (cmp:A->A->comparison) :
  SymTrans cmp -> CompatL cmp.
Proof.
 intros ST x x' y Hx. rewrite (sym y x), (sym y x'). f_equal.
 apply SymTrans_CompatR; auto.
Qed.

(** Lexicographic comparison on pairs *)

Section PairComp.
Variable A B : Type.
Variable cmpA : A -> A -> comparison.
Variable cmpB : B -> B -> comparison.
Definition pair_compare '(a,b) '(a',b') := lex (cmpA a a') (cmpB b b').

Lemma pair_compare_sym : Sym cmpA -> Sym cmpB -> Sym pair_compare.
Proof.
 intros HA HB (x,x') (y,y'). simpl.
 rewrite HA, HB. destruct cmpA; simpl; auto.
Qed.

Lemma pair_compare_trans :
  SymTrans cmpA -> Trans cmpB -> Trans pair_compare.
Proof.
 intros HA HB c (x,x') (y,y') (z,z') Hxy Hyz. simpl in *.
 destruct (cmpA x y) eqn:Cxy; simpl.
 - rewrite SymTrans_CompatL; eauto.
   destruct (cmpA y z) eqn:Cyz; simpl; eauto.
 - subst c.
   destruct (cmpA y z) eqn:Cyz; simpl; try easy.
   + flipcmp Cyz. rewrite SymTrans_CompatR, Cxy; eauto.
   + rewrite tra; eauto. easy.
 - subst c.
   destruct (cmpA y z) eqn:Cyz; simpl; try easy.
   + flipcmp Cyz. rewrite SymTrans_CompatR, Cxy; eauto.
   + rewrite tra; eauto. easy.
Qed.

Global Instance pair_compare_st :
  SymTrans cmpA -> SymTrans cmpB -> SymTrans pair_compare.
Proof.
 constructor.
 - apply pair_compare_sym; apply sym.
 - apply pair_compare_trans; auto. apply tra.
Qed.

Lemma pair_compare_eq a a' b b' :
  pair_compare (a,b) (a',b') = Eq <-> cmpA a a' = Eq /\ cmpB b b' = Eq.
Proof.
 apply lex_Eq.
Qed.

End PairComp.

(** Comparison on lists *)

Section ListComp.
Variable A : Type.
Variable cmp : A -> A -> comparison.
Fixpoint list_compare (l1 l2 : list A) :=
  match l1, l2 with
  | [], [] => Eq
  | [], _ => Lt
  | _, [] => Gt
  | x1::l1', x2::l2' => lex (cmp x1 x2) (list_compare l1' l2')
  end.

Lemma list_compare_sym : Sym cmp -> Sym list_compare.
Proof.
 intros HA. red. induction x as [|a x IH]; destruct y as [|a' y]; auto.
 simpl. rewrite HA. destruct cmp; simpl; auto.
Qed.

Lemma list_compare_trans :
  SymTrans cmp -> Trans list_compare.
Proof.
 intros HA c.
 induction x as [|a x IH]; destruct y as [|a' y], z as [|a'' z];
  simpl; auto; try congruence.
 destruct (cmp a a') eqn:E, (cmp a' a'') eqn:E'; simpl; try congruence.
 - rewrite tra; eauto. simpl; eauto.
 - intros _ <-. rewrite SymTrans_CompatL, E'; eauto.
 - intros _ <-. rewrite SymTrans_CompatL, E'; eauto.
 - intros <- _. rewrite SymTrans_CompatR, E; eauto. now flipcmp E'.
 - intros <- _. rewrite tra; eauto. easy.
 - intros <- _. rewrite SymTrans_CompatR, E; eauto. now flipcmp E'.
 - intros <- _. rewrite tra; eauto. easy.
Qed.

Global Instance list_compare_st : SymTrans cmp -> SymTrans list_compare.
Proof.
 constructor. apply list_compare_sym, sym. now apply list_compare_trans.
Qed.

Lemma list_compare_eq l l' :
  list_compare l l' = Eq <-> Forall2 (fun a a' => cmp a a' = Eq) l l'.
Proof.
 split.
 - revert l'.
   induction l as [|a l IH]; destruct l' as [|b l']; simpl; try easy.
    rewrite lex_Eq; intuition.
 - induction 1; simpl; now rewrite ?lex_Eq.
Qed.

End ListComp.
