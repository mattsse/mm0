module CAST (module CAST, AtDepType(..), SortData(..)) where

import qualified Data.Text as T
import Environment (SortData(..), DepType(..))

type Offset = Int
data AtPos a = AtPos Offset a deriving (Show)
data Span a = Span Offset a Offset deriving (Show)

instance Functor AtPos where
  fmap f (AtPos l a) = AtPos l (f a)

instance Functor Span where
  fmap f (Span l a r) = Span l (f a) r

unPos :: AtPos a -> a
unPos (AtPos _ a) = a

unSpan :: Span a -> a
unSpan (Span _ a _) = a

type AST = [AtPos Stmt]

data Visibility = Public | Abstract | Local | VisDefault deriving (Eq)
data DeclKind = DKTerm | DKAxiom | DKTheorem | DKDef deriving (Eq)
instance Show DeclKind where
  show DKTerm = "term"
  show DKAxiom = "axiom"
  show DKTheorem = "theorem"
  show DKDef = "def"

data Stmt =
    Sort Offset T.Text SortData
  | Decl Visibility DeclKind Offset T.Text
      [Binder] (Maybe [Type]) (Maybe LispVal)
  | Theorems [Binder] [LispVal]
  | Notation Notation
  | Inout Inout
  | Annot LispVal (AtPos Stmt)
  | Do [LispVal]

data Notation =
    Delimiter [Char] (Maybe [Char])
  | Prefix Offset T.Text Const Prec
  | Infix Bool Offset T.Text Const Prec
  | Coercion Offset T.Text T.Text T.Text
  | NNotation Offset T.Text [Binder] (Maybe Type) [AtPos Literal]

data Literal = NConst Const Prec | NVar T.Text

data Const = Const {cOffs :: Offset, cToken :: T.Text}
data Prec = Prec Int | PrecMax deriving (Eq)

instance Show Prec where
  show (Prec n) = show n
  show PrecMax = "max"

instance Ord Prec where
  _ <= PrecMax = True
  PrecMax <= _ = False
  Prec m <= Prec n = m <= n

type InputKind = T.Text
type OutputKind = T.Text

data Inout =
    Input InputKind [LispVal]
  | Output OutputKind [LispVal]

data Local = LBound T.Text | LReg T.Text | LDummy T.Text | LAnon deriving (Show)

data AtDepType = AtDepType (AtPos T.Text) [AtPos T.Text] deriving (Show)

unDepType :: AtDepType -> DepType
unDepType (AtDepType t ts) = DepType (unPos t) (unPos <$> ts)

data Formula = Formula Offset T.Text deriving (Show)

data Type = TType AtDepType | TFormula Formula deriving (Show)

tyOffset :: Type -> Offset
tyOffset (TType (AtDepType (AtPos o _) _)) = o
tyOffset (TFormula (Formula o _)) = o

data Binder = Binder Offset Local (Maybe Type) deriving (Show)

isLBound :: Local -> Bool
isLBound (LBound _) = True
isLBound _ = False

isLCurly :: Local -> Bool
isLCurly (LBound _) = True
isLCurly (LDummy _) = True
isLCurly _ = False

localName :: Local -> Maybe T.Text
localName (LBound v) = Just v
localName (LReg v) = Just v
localName (LDummy v) = Just v
localName LAnon = Nothing

data Syntax = Define | Lambda | Quote | If

data LispVal =
    Atom T.Text
  | List [LispVal]
  | DottedList LispVal [LispVal] LispVal
  | Number Integer
  | String T.Text
  | Bool Bool
  | LFormula Formula
  | Syntax Syntax
  | Undef
  | LispAt Offset LispVal

instance Show LispVal where
  showsPrec _ (Atom e) = (T.unpack e ++)
  showsPrec _ (List [Syntax Quote, e]) = ('\'' :) . shows e
  showsPrec _ (List ls) = ('(' :) . f ls . (')' :) where
    f [] = id
    f [e] = shows e
    f (e : es) = shows e . (' ' :) . f es
  showsPrec _ (DottedList l ls e') =
    ('(' :) . flip (foldr (\e -> shows e . (' ' :))) (l : ls) .
    (". " ++) . shows e' . (')' :)
  showsPrec _ (Number n) = shows n
  showsPrec _ (String s) = shows s
  showsPrec _ (Bool True) = ("#t" ++)
  showsPrec _ (Bool False) = ("#f" ++)
  showsPrec _ (Syntax Define) = ("#def" ++)
  showsPrec _ (Syntax Lambda) = ("#fn" ++)
  showsPrec _ (Syntax Quote) = ("#quote" ++)
  showsPrec _ (Syntax If) = ("#if" ++)
  showsPrec _ Undef = ("#<undef>" ++)
  showsPrec _ (LFormula (Formula _ f)) = ('$' :) . (T.unpack f ++) . ('$' :)
  showsPrec _ (LispAt _ e) = shows e

cons :: LispVal -> LispVal -> LispVal
cons l (List r) = List (l : r)
cons l (DottedList r0 rs r) = DottedList l (r0 : rs) r
cons l r = DottedList l [] r
