" sample.vim — comprehensive Vimscript (VimL) syntax fixture for parser testing.
" Covers: variables, functions, lambda, closures, autocommands, mappings,
" commands, lists, dicts, string ops, regex, error handling, classes (Vim9),
" and legacy + Vim9 syntax side-by-side.

" --------------------------------------------------------------------------- "
" Script-local constants
" --------------------------------------------------------------------------- "

let s:MAX_ITEMS = 100
let s:PLUGIN_NAME = 'sample'
let s:VERSION = [1, 0, 0]

" --------------------------------------------------------------------------- "
" Functions (legacy VimL)
" --------------------------------------------------------------------------- "

function! s:Greet(name, ...) abort
  let l:greeting = a:0 > 0 ? a:1 : 'Hello'
  return l:greeting . ', ' . a:name . '!'
endfunction

function! s:Fibonacci(n) abort
  if a:n <= 1
    return a:n
  endif
  return s:Fibonacci(a:n - 1) + s:Fibonacci(a:n - 2)
endfunction

function! s:Map(list, Fn) abort
  let l:result = []
  for l:item in a:list
    call add(l:result, a:Fn(l:item))
  endfor
  return l:result
endfunction

function! s:Filter(list, Pred) abort
  return filter(copy(a:list), {_, v -> a:Pred(v)})
endfunction

function! s:Reduce(list, Fn, init) abort
  let l:acc = a:init
  for l:item in a:list
    let l:acc = a:Fn(l:acc, l:item)
  endfor
  return l:acc
endfunction

" --------------------------------------------------------------------------- "
" Lambda / closures
" --------------------------------------------------------------------------- "

let s:square = {x -> x * x}
let s:double = {x -> x * 2}
let s:add    = {a, b -> a + b}

let s:pipeline = {val, fns ->
      \ s:Reduce(fns, {acc, fn -> fn(acc)}, val)}

" --------------------------------------------------------------------------- "
" Lists & dicts
" --------------------------------------------------------------------------- "

let s:fruits = ['apple', 'banana', 'cherry', 'date']
let s:nums   = range(1, 10)

let s:config = {
      \ 'host':    'localhost',
      \ 'port':    8080,
      \ 'debug':   v:true,
      \ 'tags':    ['a', 'b'],
      \ }

" Deep copy
let s:config_copy = deepcopy(s:config)

" Sorting
let s:sorted = sort(copy(s:fruits), {a, b -> a > b ? 1 : a < b ? -1 : 0})

" --------------------------------------------------------------------------- "
" String operations
" --------------------------------------------------------------------------- "

let s:raw    = '  Hello, World!  '
let s:trimmed = trim(s:raw)
let s:upper  = toupper(s:trimmed)
let s:lower  = tolower(s:trimmed)
let s:parts  = split('one:two:three', ':')
let s:joined = join(s:parts, ' | ')
let s:replaced = substitute(s:trimmed, 'World', 'Vim', 'g')
let s:len    = len(s:trimmed)

" Regex
if s:trimmed =~# '^Hello'
  let s:matched = matchstr(s:trimmed, '\w\+')
endif

" --------------------------------------------------------------------------- "
" Control flow
" --------------------------------------------------------------------------- "

function! s:Classify(score) abort
  if a:score >= 90
    return 'A'
  elseif a:score >= 80
    return 'B'
  elseif a:score >= 70
    return 'C'
  else
    return 'F'
  endif
endfunction

function! s:DescribeStatus(status) abort
  if a:status ==# 'pending'
    return 'Waiting'
  elseif a:status ==# 'running'
    return 'In progress'
  elseif a:status ==# 'done'
    return 'Completed'
  elseif a:status ==# 'failed'
    return 'Failed'
  else
    return 'Unknown: ' . a:status
  endif
endfunction

" --------------------------------------------------------------------------- "
" Error handling
" --------------------------------------------------------------------------- "

function! s:SafeDivide(a, b) abort
  if a:b == 0
    throw 'DivisionByZero: cannot divide ' . a:a . ' by 0'
  endif
  return a:a / a:b
endfunction

function! s:TryCall(Fn, ...) abort
  try
    return call(a:Fn, a:000)
  catch /DivisionByZero/
    echoerr 'Caught: ' . v:exception
    return v:null
  finally
    " always runs
  endtry
endfunction

" --------------------------------------------------------------------------- "
" Commands
" --------------------------------------------------------------------------- "

command! -nargs=1 -complete=file SampleOpen
      \ call s:OpenFile(<f-args>)

command! -nargs=0 SampleInfo
      \ echo 'Sample v' . join(s:VERSION, '.')

function! s:OpenFile(path) abort
  if !filereadable(a:path)
    echoerr 'File not readable: ' . a:path
    return
  endif
  execute 'edit ' . fnameescape(a:path)
endfunction

" --------------------------------------------------------------------------- "
" Mappings
" --------------------------------------------------------------------------- "

nnoremap <silent> <leader>si :SampleInfo<CR>
nnoremap <silent> <leader>sg :call <SID>Greet('World')<CR>

inoremap <expr> <Tab>
      \ pumvisible() ? "\<C-n>" : "\<Tab>"

" --------------------------------------------------------------------------- "
" Autocommands
" --------------------------------------------------------------------------- "

augroup SamplePlugin
  autocmd!
  autocmd BufWritePre *.vim :%s/\s\+$//e
  autocmd BufReadPost *.log setlocal nowrap
  autocmd FileType python setlocal tabstop=4 shiftwidth=4 expandtab
augroup END

" --------------------------------------------------------------------------- "
" Vim9 script section (Vim 9.0+)
" --------------------------------------------------------------------------- "

if has('vim9script')
  vim9script

  const MaxSize: number = 100

  def Fibonacci9(n: number): number
    if n <= 1
      return n
    endif
    return Fibonacci9(n - 1) + Fibonacci9(n - 2)
  enddef

  class Counter
    var count: number = 0

    def Increment(by: number = 1): void
      this.count += by
    enddef

    def Reset(): void
      this.count = 0
    enddef

    def Value(): number
      return this.count
    enddef
  endclass

  interface Describable
    def Describe(): string
  endinterface

  def Run(): void
    var c = Counter.new()
    c.Increment()
    c.Increment(5)
    echo $'Counter: {c.Value()}'
    echo $'Fib(10): {Fibonacci9(10)}'
  enddef

  Run()
endif

" --------------------------------------------------------------------------- "
" Entry point (legacy)
" --------------------------------------------------------------------------- "

call s:TryCall(function('s:SafeDivide'), 10, 0)
echo s:Greet('World')
echo map(range(10), {_, i -> s:Fibonacci(i)})
