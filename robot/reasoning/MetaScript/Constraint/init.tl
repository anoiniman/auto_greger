global enum ConstType
    "NONE"

    "item"
    "building"
    "quest"
end

global enum ConstReturnEnum
    "Available"
    "Block"
    "Done"
end

global interface ConstReturn<T>
    ret_type: ConstReturnEnum
    ret_obj: T | nil
end


-- (revised) lock meaning:
-- 0 == Never Touched Before
-- 1 == Working on It (Block)
-- 2 == Working on It (Please Recheck)

-- 3 == Done It once  (Could retriger == false)
-- 4 == Blocked for waiting

global enum LockState
    "Free"
    "Block-Working"
    "Block-Recheck"
    "Done"

    "Wait"
end

global interface Constraint<T>
where self.const_type == "NONE"
    const_type: ConstType
    do_once: boolean

    check: function(self): ConstReturn<T>
end
