#!/usr/bin/env coffee

#_ = require 'underscore'
_ = require 'lodash'


#############################################################################
# The format is of the form NNNxMMM:N.N.N/N.N
# Where NNN is the number of columns, MMM is the number of rows
#   and the '/' delimits blocks, with the column info first, then the row
# info e.g.  3x4:3/1/2/2/1/1.1/1
#   corresponds to the puzle
#      3 1 2
#    2 ? ? ?
#    1 ? ? ?
#  1 1 ? ? ?
#    1 ? ? ?
# This function parses such a string and returns the puzzle.
#############################################################################
parse = (str) ->

  [dims, info] = str.split ':'
  [cols,rows] = dims.split 'x'
  infos = info.split '/'
  infos = _.map infos, (info) -> _.map (info.split '.'), (s) -> parseInt s, 10
  puzzle =
    rows: rows
    columns: cols
    columnInfo: ({index: i, blocks: blocks} for blocks,i in infos.slice(0,cols))
    rowInfo: ({index: i, blocks: blocks} for blocks,i in infos.slice(cols,rows+cols))
  return puzzle
#############################################################################



#############################################################################
# Utility function to sum up an array.
#############################################################################
sum = (arr) -> _.reduce arr, ((m,b) -> m+b), 0
#############################################################################



#############################################################################
# Pretty print a grid, with 'B' for black and 'W' for white.
# Unknowns are '?'.
#############################################################################
prettyPrint = (grid) ->

  result = ""
  for row in grid
    for e in row
      if e is 1 then c = 'B'
      if e is -1 then c = 'W'
      if e is 0 then c = '?'
      result += c
    result += '\n'
  return result.slice(0, result.length-1)
#############################################################################



#############################################################################
# Given a number of possibilities such as
#   [ 1, 1, 0, 0,-1]
#   [-1, 0, 1, 0,-1]
#   [ 1, 1, 1, 1,-1]
# combine them in such a way that if all are 1 in the same position
# then the result has a 1 at that position. Likewise for -1. Otherwise
# there is a 0 at that position.
# So, for the example above, the answer should be
#   [ 0, 0, 0, 0,-1]
#############################################################################
combine = (arrs) ->

  result = []
  newArrs = _.zip arrs...
  for arr in newArrs
    if (_.all arr, (a) -> a is 1)
      result.push 1
    else if (_.all arr, (a) -> a is -1)
      result.push -1
    else
      result.push 0
  return result
#############################################################################



#############################################################################
# Given a number of possibilities and a template,
# remove all those possibilities that aren't compatible
# with the template.
#############################################################################
filter = (poss, template) -> 

  _.filter poss, (arr) ->
    zs = _.zip arr, template
    return _.all zs, (z) -> 
      if z[0] isnt -z[1] then true
      else false
#############################################################################


cache = {}
#############################################################################
# Given  some block information and a size to fit them in,
# return all the possibilities.
# e.g. with blocks of [1,2] and size of 5 should return
#   [1,-1,1,1,-1]
#   [1,-1,-1,1,1]
#   [-1,1,-1,1,1]
# where 1 denotes filled, -1 denotes unfilled.
#############################################################################
possibilities = (blocks, size) ->

  key = "#{JSON.stringify blocks}:::#{size}"
  if cache[key]?
    return cache[key]

  if blocks.length is 0
    result = [[]]
    for i in [1..size] by 1
      result[0].push -1
    return result

  if blocks[0] is 0
    return possibilities(blocks.slice(1), size)

  if blocks.length is 1
    restLength = 0
  else
    restLength = -2 + blocks.length + (sum blocks.slice(1))

  result = []
  for i in [0..size-restLength-blocks[0]] by 1
    prelude = []
    for j in [0..i-1] by 1
      prelude.push -1
    for j in [1..blocks[0]]
      prelude.push 1
    if restLength > 0 then prelude.push -1
    newSize = size - prelude.length
    newResults = possibilities blocks.slice(1), newSize
    for newResult in newResults
      result.push (prelude.concat newResult)

  cache[key] = result
  return result
#############################################################################



#############################################################################
# Initialise a grid, by filling with 0.
#############################################################################
initialise = (rows, cols) ->

  grid = []
  row = []
  row.push 0 for i in [1..cols]
  grid.push row.slice() for j in [1..rows]
  return grid
#############################################################################



#############################################################################
# Using the row info, perform a single pass on the rows filling in as much
# info as possible.
#############################################################################
deduceRows = (grid, rowInfo, size, affectedRows) ->
  affectedColumns = []
  last = JSON.stringify grid
  for i in affectedRows
    info = rowInfo[i]
    #for info in rowInfo
    blocks = info.blocks
    row = info.index
    poss = possibilities blocks, size
    gRow = grid[row]
    poss2 = filter poss, gRow
    newRow = combine poss2
    aff = (i for [o,n],i in (_.zip gRow, newRow) when o isnt n)
    affectedColumns = affectedColumns.concat aff
    grid[row] = newRow
  affectedColumns = _.uniq affectedColumns
  return [grid, affectedColumns]
#############################################################################



#############################################################################
# Using the column info, perform a single pass on the columns filling in as
# much info as possible.
#############################################################################
deduceColumns = (grid, columnInfo, size, affectedColumns) ->
  flippedGrid = _.zip grid...
  [flippedGrid, affectedRows] = deduceRows flippedGrid, columnInfo, size, affectedColumns
  unflippedGrid = _.zip flippedGrid...
  return [unflippedGrid, affectedRows]
#############################################################################



#############################################################################
# Fill in as much of the puzzle as possible deductively
#############################################################################
# i.e., with no guessing.
deduce = (grid, puzzle) ->

  last = null
  affectedRows = [0..puzzle.rows-1]
  affectedColumns = [0..puzzle.columns-1]
  [grid, xxx] = deduceColumns grid, puzzle.columnInfo, puzzle.rows, affectedColumns
  while last isnt JSON.stringify grid
    last = JSON.stringify grid
    [grid, affectedColumns] = deduceRows grid, puzzle.rowInfo, puzzle.columns, affectedRows
    if affectedColumns.length is 0 then break
    [grid, affectedRows] = deduceColumns grid, puzzle.columnInfo, puzzle.rows, affectedColumns
    if affectedRows.length is 0 then break

    #console.log (_.filter (_.flatten grid), (e) -> e is 0).length
  return grid
#############################################################################



#############################################################################
# Check if the given grid is complete.
#############################################################################
isComplete = (grid) ->
  return _.all (_.flatten grid), (e) -> e isnt 0
#############################################################################



#############################################################################
# Solve the given puzzle.
#############################################################################
solvePuzzle = (puzzle) ->
  grid = initialise puzzle.rows, puzzle.columns
  return solve grid, puzzle
#############################################################################



#############################################################################
# Solve the puzzle given the grid.
#############################################################################
solve = (grid, puzzle) ->

  grid = deduce grid, puzzle

  if not isComplete grid
    storedGrid = JSON.stringify grid
    for info in puzzle.rowInfo
      blocks = info.blocks
      row = info.index

      poss = possibilities blocks, puzzle.columns
      gRow = grid[row]
      poss2 = filter poss, gRow
      hmm = combine poss2
      if (JSON.stringify hmm) is (JSON.stringify gRow) and  (_.any hmm, (h) -> h is 0)
        for p in poss2
          testGrid = JSON.parse storedGrid
          testGrid[row] = p
          finalGrid = solve testGrid, puzzle
          if isComplete finalGrid then return finalGrid

    grid = _.zip grid...
    for info in puzzle.columnInfo
      blocks = info.blocks
      row = info.index

      poss = possibilities blocks, puzzle.rows
      gRow = grid[row]
      poss2 = filter poss, gRow
      hmm = combine poss2
      if (JSON.stringify hmm) is (JSON.stringify gRow) and  (_.any hmm, (h) -> h is 0)
        for p in poss2
          testGrid = _.zip (JSON.parse storedGrid)...
          testGrid[row] = p
          finalGrid = solve (_.zip testGrid...), puzzle
          if isComplete finalGrid then return finalGrid
      ++row

  return grid
#############################################################################


inputs = process.argv[2...]
str = inputs[0]
puzzle = parse str
solution = solvePuzzle puzzle
console.log prettyPrint solution

