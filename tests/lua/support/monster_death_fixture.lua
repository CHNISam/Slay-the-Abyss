-- The source action queue may finish before the independently clocked native
-- monster fade. Observe its real completion before checking the remaining row.
return function(host,ui,id)
    for _=1,120 do
        if not ui.feedback.dying[id] then return end
        host:update(.05)
    end
    assert(not ui.feedback.dying[id],'source monster death did not finish')
end
