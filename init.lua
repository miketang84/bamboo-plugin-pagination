module (..., package.seeall)

local plugin = require 'bamboo.plugin'

local plugin_name = 'pagination'
local path='../plugins/pagination/views/'
local TMPLS = {
	['pagin_a_ajaxpage'] = path .. 'pagin_a_ajaxpage.html',
	['pagin_select_ajax'] = path .. 'pagin_select_ajax.html',	
	['pagin_a'] = path .. 'pagin_a.html',
	['pagin_select'] = path .. 'pagin_select.html',		
	['pagin_a_ajax_new'] = path .. 'pagin_a_ajax_new.html',		
	['pagin_power'] = path .. 'pagin_power.html',
	['pagin_power2'] = path .. 'pagin_power2.html',
	['pagin_trad'] = path .. 'pagin_trad.html',
}

local makeGeneratorParams = function (generator, starti, endi, is_rev)
	table.remove(generator, 2)
	table.remove(generator, 1)
	if is_rev == 'rev' then
		table.insert(generator, -endi)
		table.insert(generator, -starti)
		table.insert(generator, 'rev')					
	
	else
		table.insert(generator, starti)
		table.insert(generator, endi)
	end
	
	return generator
end

function helper(_args)
	local params = req.PARAMS
	
	local thepage = tonumber(params.thepage) or tonumber(_args.thepage) or 1
	if thepage < 1 then thepage = 1 end
--	local totalpages = tonumber(params.totalpages) or 1
--	if totalpages and thepage > totalpages then thepage = totalpages end
	
	local npp = tonumber(params.npp) or tonumber(_args.npp) or 5
	local starti = (thepage-1) * npp + 1
	local endi = thepage * npp
	local paginurl = params.paginurl or _args.paginurl
	local callback = _args.callback
	
	local totalnum, htmlcontent, headcontent, tailcontent
	local datasource
	if not _args.callback then
		-- assert(_args.content_tmpl)
		-- if supply datasource
		if _args.orig_datasource then
			datasource = List(_args.orig_datasource) or List()
			totalnum = #datasource

			datasource = datasource:slice(starti, endi)
			_args.datasource = datasource
			
		else
			-- if supply model name, query_args, is_rev
			local generator = table.copy(_args.generator)
			assert(type(generator) == 'table')
			local method = generator[2]
			assert(type(method) == 'string')
			if method == 'filter' then
				local model = bamboo.getModelByName(generator[1])			
				assert(isClass(model))				
				generator = makeGeneratorParams(generator, starti, endi, _args.is_rev)
				datasource = model:filter(unpack(generator))
				totalnum = model:count(unpack(generator))
				print('---', totalnum, #datasource)
				
			elseif method == 'getForeign' then
				local v = generator[1]
				assert(isInstance(v))
				generator = makeGeneratorParams(generator, starti, endi, _args.is_rev)
				datasource = v:getForeign(unpack(generator))				
				totalnum = v:numForeign(unpack(generator))
				
			elseif method == 'slice' then
				local model = bamboo.getModelByName(generator[1])			
				assert(isClass(model))
				generator = makeGeneratorParams(generator, starti, endi, _args.is_rev)
				datasource = model:slice(unpack(generator))
				totalnum = model:numbers()
				
			elseif method == 'getCustomQuerySet' then
				local model = bamboo.getModelByName(generator[1])			
				assert(isClass(model))
				generator = makeGeneratorParams(generator, starti, endi, _args.is_rev)
				datasource = model:getCustomQuerySet(unpack(generator))
				totalnum = model:numCustom(unpack(generator))
			
			end

			_args.datasource = datasource
			_args.totalnum = totalnum
		end
		
		if totalnum then
			totalpages = math.ceil(totalnum/npp)
			if thepage > totalpages	then thepage = totalpages end
		end
		_args.thepage = thepage
		_args.totalpages = totalpages
			
            	if _args.inline_tmpl then 
			htmlcontent = View(_args.inline_tmpl, 'inline')(_args)
		else
			htmlcontent = View(_args.content_tmpl)(_args)
		end
			
		if thepage == 1 then
			if _args.head_inline then 
				headcontent = View(_args.head_inline, 'inline')(_args)
			end
				
			if _args.tail_inline then 
				tailcontent = View(_args.tail_inline, 'inline')(_args)
			end
		end

	else
		-- if supply callback
		if type(callback) == 'string' then
			local callback_func = bamboo.getPluginCallbackByName(callback)
			assert(type(callback_func) == 'function')
			-- the callback should return 2 values: html fragment and totalnum
			htmlcontent, totalnum = callback_func(starti, endi)
		elseif type(callback) == 'function' then
			htmlcontent, totalnum = callback(starti, endi)
		end
	end
	local prevpage = thepage - 1
	if prevpage < 1 then prevpage = 1 end
	local nextpage = thepage + 1
	if nextpage > totalpages then nextpage = totalpages end
	
    	return {
		['_tag'] = _args._tag,
		['totalnum'] = totalnum,
		['htmlcontent'] = htmlcontent, 
		['totalpages'] = totalpages, 
		['npp'] = npp, 
		['paginurl'] = paginurl, 
		['thepage'] = thepage, 
		['prevpage'] = prevpage, 
		['nextpage'] = nextpage,
		
		['headcontent'] = headcontent,
		['tailcontent'] = tailcontent,
		['js_callback'] = _args.js_callback
	}
end

function page(web, req)
	local params = req.PARAMS
	assert(params._tag, '[Error] @plugin pagination function page - missing _tag.')
	local _args = plugin.unpersist(plugin_name, params._tag)
	
	return web:page(View(TMPLS[_args.tmpl])(helper(_args)))
end

function json(web, req)
	local params = req.PARAMS
	assert(params._tag, '[Error] @plugin pagination function json - missing _tag.')
	local _args = plugin.unpersist(plugin_name, params._tag)

	return web:jsonSuccess(helper(_args))
end


--[==[

{^ pagination 
datasource=all_persons,
inline_tmpl = inline_variable,
content_tmpl="item.html", 
npp=20,
paginurl = 'xxxxx',
pagin_datatype = 'json',
thepage = n,

head_tmpl = 'head.html',
head_inline = xxx,
tail_tmpl = 'tail.html',
tail_inline = xxx,

generator = {'Model', 'filter', query_args, ...}
generator = {v, 'getForeign', field, start, stop, is_rev}
generator = {'Model', 'slice', start, stop, is_rev}
generator = {'Model', 'getCustomQuerySet', key, start, stop, is_rev}

jscallback = [[
	js code here
]]

^}

--]==]
function main(args, env)
	assert(args._tag, '[Error] @plugin pagination - missing _tag.')
	--assert(args.paginurl, '[Error] @plugin pagination - missing paginurl.')

	-- default choose pagin_a style
	args.tmpl = args.tmpl or 'pagin_select_ajax'
	if not args.paginurl then
		local purl = '/pagination/'..args._tag..'/page/'
		local jurl = '/pagination/'..args._tag..'/json/'
		local urls = {
			[purl] = page,
			[jurl] = json,
		}
		table.update(bamboo.URLS, urls)
		args.paginurl = args.pagin_datatype == 'json' and jurl or purl
	end
	
	if args.datasource then
		args.orig_datasource = args.datasource
	end

	plugin.persist(plugin_name, args)

	return View(TMPLS[args.tmpl]) (helper(args))
end

