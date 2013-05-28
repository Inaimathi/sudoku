module Sudoku where

import Data.Set (Set(..), toList, fromList, difference, member)
import qualified Data.Set as Set
import Data.List (sort, sortBy, intercalate, group, find)
import Data.List.Split (chunksOf)
import Data.Ord (comparing)
import Data.Char (intToDigit)
import Data.Maybe (fromJust)

---------- Class Definition, constructors and sample data
data Board = Board { values :: [[Int]], 
                     empty :: Set (Int, Int),
                     size :: Int, 
                     ixs :: [Int],
                     blockSize :: Int } deriving (Eq)

instance Show Board where
  show board = unlines . intercalate hdelim . split . lns $ values board
    where lns = map (intercalate "|" . split . map sq)
          split = chunksOf bs
          sq n = if n == 0 then ' ' else intToDigit n
          hdelim = [replicate (size board + (bs - 1)) '-']
          bs = blockSize board

sample = toBoard [[0,7,1,4,0,0,0,0,5],
                  [0,0,0,0,5,0,0,8,0],
                  [0,0,3,9,0,7,6,0,0],
                  [0,0,0,0,0,1,0,0,0],
                  [0,9,0,8,0,6,0,0,3],
                  [0,0,0,0,0,0,8,2,0],
                  [0,6,0,0,4,0,7,0,8],
                  [3,0,0,0,0,0,0,9,0],
                  [0,0,0,0,8,5,0,0,0]]

toBoard :: [[Int]] -> Board
toBoard values = findEmpties $ Board { values = values, empty = fromList [],
                                       size = len, ixs = [0..len - 1], blockSize = bs }
  where bs = fromEnum . sqrt . toEnum $ length values
        len = length values

findEmpties :: Board -> Board
findEmpties board = board { empty = fromList [(x, y) | y <- is, x <- is, blank (x, y)] }
  where blank (x, y) = 0 == ((values board) !! y !! x)
        is = ixs board

---------- The solver
main board = rec [solve [obvious, blockwise] board]
  where solved board = 0 == (Set.size $ empty board)
        rec boards = case find solved $ boards of
          Just b -> b
          Nothing -> rec $ map (solve [obvious, blockwise]) $ concatMap guess boards

solve :: [(Board -> Board)] -> Board -> Board
solve functions board = rec functions board
  where rec [] board = board -- failed :(
        rec fns board = case Set.size $ empty new of
          0 -> new -- solved :D
          _ -> rec nextFns new
          where new = (head fns) board
                nextFns = if new == board then tail fns else functions

---------- The solve stages
obvious :: Board -> Board
obvious board = findEmpties $ board { values = newVals }
  where newVals = [[newVal (x, y) | x <- ixs board] | y <- ixs board]
        ps x y = toList $ possibilities board (x, y)
        newVal (x, y) = case ((values board) !! y !! x, ps x y) of
          (0, [val]) -> val
          (val, _) -> val

blockwise :: Board -> Board
blockwise board = findEmpties $ board { values = new }
  where new = [[newVal (x, y) | x <- ixs board] | y <- ixs board]
        newVal (x, y) = case find (\(x', y', v) -> (x == x') && (y == y')) uniques of
          Just (_, _, v) -> v
          Nothing -> (values board) !! y !! x
        uniques = concat [uniqueInBlock board (x, y) | y <- bIxs, x <- bIxs]
        bIxs = [0, bs..size board-1]
        bs = blockSize board

guess board = map (\v -> findEmpties $ board { values = newVals v }) vs
  where (x, y, vs) = head $ sortBy (comparing (length . thd)) posMap
        newVals v = [[if x == x' && y == y' then v else (values board) !! y' !! x' | x' <- ixs board] | y' <- ixs board]
        posMap = [(x, y, toList $ possibilities board (x, y)) | (x, y) <- es]
        es = toList $ empty board


---------- Solver-related utility
possibilities :: Board -> (Int, Int) -> Set Int
possibilities board (x, y) = foldl difference (fromList [1..size board]) sets
  where sets = mapply (board, (x, y)) [row, col, block]

row :: Board -> (Int, Int) -> Set Int
row board (x, y) = fromList $ values board !! y

col :: Board -> (Int, Int) -> Set Int
col board (x, y) = fromList . map (!! x) $ values board

block :: Board -> (Int, Int) -> Set Int
block board (x, y) = fromList . concat . square $ values board
  where square = map (take bs . drop (origin x)) . take bs . drop (origin y)
        origin n = bs * intFloor n bs
        bs = blockSize board

uniqueInBlock board (x, y) = singles $ concatMap (toList . thd) posMap
  where posMap = [(x', y', possibilities board (x', y')) | (x', y') <- es]
        es = blockEmpties board (x, y)
        singles = map (findInMap . head) . filter ((==1) . length) . group . sort
        findInMap n = let (x, y, p) = fromJust $ find (member n . thd) posMap
                      in (x, y, n)

blockEmpties :: Board -> (Int, Int) -> [(Int, Int)]
blockEmpties board (x, y) = [(x', y') | x' <- xs, y' <- ys, blank (x', y')]
  where blank (x, y) = 0 == ((values board) !! y !! x)
        xs = [ox..ox + bs-1]
        ys = [oy..oy + bs-1]
        [ox, oy] = map origin [x, y]
        origin n = bs * intFloor n bs
        bs = blockSize board

---------- General Utility
mapply :: (a, b) -> [(a -> b -> c)] -> [c]
mapply args fns = map (\fn -> uncurry fn $ args) fns

intFloor :: Int -> Int -> Int
intFloor a b = fromEnum . floor . toEnum $ a `div` b

thd :: (a, b, c) -> c
thd (a, b, c) = c