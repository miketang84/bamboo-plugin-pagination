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

function helper(_args, req)
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

	-- assert(_args.content_tmpl)
	-- if supply datasource
	if #_args.datasource then
		datasource = List(_args.datasource) or List()
		
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
			
		elseif method == 'getForeign' then
			local v = generator[1]
			assert(isInstance(v))
			generator = makeGeneratorParams(generator, starti, endi, _args.is_rev)
			-- no appending filter part
			if type(generator[2]) == 'number' then
				datasource = v:getForeign(unpack(generator))				
				totalnum = v:numForeign(unpack(generator))
			elseif generator[2] == 'filter' then
				-- now generator[1] is 'field', generator[2] is 'filter'
				local query_set = v:getForeign(generator[1])
				table.remove(generator, 2)
				table.remove(generator, 1)					
				-- need to let filter to return the total number of fit elements
				datasource, totalnum = query_set:filter(unpack(generator))
			end
			
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
	assert(params.tag, '[Error] @plugin pagination function page - missing _tag.')
	local _args = plugin.unpersist(plugin_name, params.tag)
	
	return web:page(View(TMPLS[_args.tmpl])(helper(_args)))
end

function json(web, req)
	local params = req.PARAMS
	assert(params.tag, '[Error] @plugin pagination function json - missing _tag.')
	local _args = plugin.unpersist(plugin_name, params.tag)

	return web:jsonSuccess(helper(_args))
end


--[==[

{^ pagination

	tag = <唯一标识符>;
	datasource = <数据源，一个对象数组>;
	tmpl = <选择分页形式（模板）>;
	type = <选择是传统页面整体刷新形式，还是ajax形式 page|ajax>;
	
	totalCount = <要分页的目标总数>;
	numPerPage = <每页的条目数>;
	currentPage = <当前页数>;
	
	contentPart = <内容区页面模板文件>;
	inlineContentPart = <内容区页面字符串>;
	
	headPart = <头部区页面模板文件>;
	inlineHeadPart = <头部区页面字符串>;
	
	tailPart = <尾部区页面模板文件>;
	inlineTailPart = <尾部区页面字符串>;
	
	pagUrl = <指定点击分页器上的按钮时，向哪个URL发送请求>;
	pagRetType = <指定返回的结果类型，是返回页面，还是返回json. html|json>;

	-- 如果datasource参数的数组部分为空，则下面的起作用
	datasource = {
		model = <模型名称>,
		instance = <对象>,
		action = <操作名称 filter|slice|getQuerySet|getForeign>,
		
		query_args = <action为filter时，需要提供的查询表达式参数>,
		key ＝ <action为getQuerySet时，需要提供的key>,
		start = <action为slice时，需要提供的起始点>,
		stop = <action为slice时，需要提供的结束点>,
		is_rev = <action为slice时，是否对结果反向>,
		
		field ＝ <action为getForeign时，外键field>,
		fields = <action为slice或getQuerySet时，需要限制的返回的字段集>,
	};
	
	jscallback = [[
		js code here
	]]
^}

一些说明：
1. type不写或为page时，是页面整体刷新，整体刷新时，pagUrl, pagRetType都没有作用；
2. 在整体刷新时，args参数不需要存。；
3. datasource为数组时，总是与整体刷新一起出现的。因此，对于ajax请求来说，datasource这个值一定不为数组


--]==]




function main(args, env)
	assert(args.tag, '[Error] @plugin pagination - missing tag.')
	assert(args.datasource, '[Error] @plugin pagination - missing datasource.')

	-- default choose pagin_a style
	args.tmpl = args.tmpl or 'pagin_select_ajax'
	
	if args.type == 'ajax'
		if not args.pagUrl then
			-- 页面整体刷新的情况，用不到下面这两个URL
			-- 下面这两个都是ajax下的。一个返回页面片断，一个返回json数据
			local purl = '/pagination/html/'..args.tag
			local jurl = '/pagination/json/'..args.tag
			local urls = {
				[purl] = page,
				[jurl] = json,
			}
			table.update(bamboo.URLS, urls)
			args.pagUrl = args.pagRetType == 'json' and jurl or purl
		end
		
		-- 对于每次点击分页按钮，页面整体刷新的情况，相当于每次都会执行一次pagination插件
		-- 因此不需要存储args这个中间信息，每次渲染页面，都会把新的分页的状态信息和新的数据源传到插件里面来
		
		-- 当使用ajax方式时，因为插件代码(main函数)只在渲染整体页面的时候执行一次，需要把这些参数信息存储在
		-- redis中，下次翻页时，再取出来。这里面要注意的是，datasource这个值不要存储。其它都可以存。减少存储量
		-- 并且存了也没用。不过，在使用ajax时，datasource这个值不会是数组。
		plugin.persist(plugin_name, args.tag, args)
	end

	return View(TMPLS[args.tmpl]) (helper(args))
end

