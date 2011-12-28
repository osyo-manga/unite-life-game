scriptencoding utf-8

function! unite#sources#life_game#define()
	return s:source
endfunction

function! s:rand(n)
	let match_end = matchend(reltimestr(reltime()), '\d\+\.') + 1
	let rand = reltimestr(reltime())[match_end : ] % (a:n + 1)
	return rand
endfunction

function! s:sides(buffer, x, y)
	return [
\		a:buffer[a:y+0][a:x+1],
\		a:buffer[a:y+1][a:x+1],
\		a:buffer[a:y+1][a:x+0],
\		a:buffer[a:y+1][a:x-1],
\		a:buffer[a:y+0][a:x-1],
\		a:buffer[a:y-1][a:x-1],
\		a:buffer[a:y-1][a:x-0],
\		a:buffer[a:y-1][a:x+1],
\	]
endfunction

function! s:getchar()
	let c = getchar()
	return type(c) == type(0) ? nr2char(c) : c
endfunction

function! s:life_game(life, death)
	let self = {}
	let self.life = a:life
	let self.code_size = len(a:life)/2+1
	let self.death = len(a:life) == len(a:death) ? a:death : self.code_size == 2 ? "　" : " "
	let self.height = winheight(0)-7
	let self.width  = winwidth(0)/self.code_size-8/self.code_size
	let self.is_stop = 0
	let width  = self.width
	let height = self.height
	let self.buffer = map(range(height), "map(range(width), 'self.death')")

	function! self.reset()
		let width  = self.width
		let height = self.height
		let buffer = map(range(height), "map(range(width), 'self.death')")
		if self.code_size == 2
			let buffer[0] = map(range(width), "'ー'")
			let buffer[height-1] = map(range(width), "'ー'")
			for y in range(height)
				let buffer[y][0] = "｜"
				let buffer[y][width-1] = "｜"
			endfor
			let buffer[0][0] = "＋"
			let buffer[0][width-1] = "＋"
			let buffer[height-1][width-1] = "＋"
			let buffer[height-1][0] = "＋"
		else
			let buffer[0] = map(range(width), "'-'")
			let buffer[height-1] = map(range(width), "'-'")
			for y in range(height)
				let buffer[y][0] = "|"
				let buffer[y][width-1] = "|"
			endfor
			let buffer[0][0] = "+"
			let buffer[0][width-1] = "+"
			let buffer[height-1][width-1] = "+"
			let buffer[height-1][0] = "+"
		endif
		let self.buffer = buffer
	endfunction

	function! self.set_rand()
		for n in range(self.height*self.width/4)
			let self.buffer[s:rand(self.height-3)+1][s:rand(self.width-3)+1] = self.life
		endfor
	endfunction
	
	function! self.set_acorn()
		let buffer = self.buffer
		let life = self.life
		call self.reset()
		let buffer[5][7] = life
		let buffer[6][9] = life
		let buffer[7][6] = life
		let buffer[7][7] = life
		let buffer[7][10] = life
		let buffer[7][11] = life
		let buffer[7][12] = life
	endfunction

	function! self.update()
		let buffer = self.buffer
		let width  = self.width
		let height = self.height
		let life   = self.life
		let death  = self.death
		let result = deepcopy(buffer)

		" 生存処理
		if !self.is_stop
			for y in range(1, height - 2)
				for x in range(1, width - 2)
					if buffer[y][x] == death
						let buffer[y][x] = count(s:sides(result, x, y), life) == 3 ? life : death
					elseif buffer[y][x] == life
						let sides_num = count(s:sides(result, x, y), life)
						let buffer[y][x] = sides_num == 2 || sides_num == 3 ? life : death
					else
						let buffer[y][x] = death
					endif
				endfor
			endfor
		else
			" 適当な wait
			for n in range(100 * 500)
			endfor
		endif

		" マウスのクリック位置に追加
		if getchar(1)
			let c = s:getchar()
			echom c
			if c == "1"
				let self.is_stop = self.is_stop ? 0 : 1
			elseif c == "2"
				call self.set_rand()
			elseif c == "3"
				call self.reset()
			endif
			let code_size = len(life)/2+1
			let x = (v:mouse_col-5)/self.code_size
			let y = (v:mouse_lnum-4)
			if 1 <= x && x <= width-1 && 1 <= y && y <= width-1
				let self.buffer[y][x] = self.buffer[y][x] == life ? death : life
			endif
		endif
		return result
	endfunction

	call self.reset()
	call self.set_rand()
	
	return self
endfunction


let s:source = {
\	"name" : "life-game",
\	"description" : "life game",
\	"syntax" : "uniteSource_life_game",
\	"life_game" : {},
\	"hooks" : {}
\}
let s:source.hooks.source = s:source

function! s:source.hooks.on_init(args, context)
	let life = len(a:args) >= 1 ? a:args[0] : "x"
	let death = len(a:args) >= 2 ? a:args[1] : " "

	let self.source.life_game = s:life_game(life, death)
endfunction

function! s:source.hooks.on_syntax(args, context)
" 	let life = self.source.life
" 	execute "syntax match life /".life."/ containedin=uniteSource_life_game"
" 	highlight life ctermfg=green ctermbg=green guibg=green guifg=green
endfunction

function! s:source.async_gather_candidates(args, context)
	let a:context.source.unite__cached_candidates = []

	" ライフゲーム本体の更新
	let result = self.life_game.update()
	
	let life_num = eval(join(map(deepcopy(result), "count(v:val, self.life_game.life)"), "+"))
	let header = "[life:".life_num."]"
 	let header = header."   ".(self.life_game.is_stop ? "stop" : "start")
	let fotter = "1:[start/stop]  2:[set random]  3:[reset]  mouse:[life/death]"
	return
\		  [ {"word" : header, "dummy" : 1} ]
\		+ map(result, '{"word" : join(v:val, ""), "dummy" : 1}')
\		+ [ {"word" : fotter, "dummy" : 1} ]
endfunction


