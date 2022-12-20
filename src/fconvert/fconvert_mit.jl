"""
    fconvert(F_to, MIT_from::MIT)

Convert the time MIT `MIT_from` to the desired frequency `F_to`.
"""
fconvert(F_to::Type{<:Frequency}, MIT_from::MIT; args...) = error("""
Conversion of MIT from $(frequencyof(MIT_from)) to $F_to not implemented.
""")

# do nothing when the source and target frequencies are the same.
fconvert(F_to::Type{F}, MIT_from::MIT{F}) where {F<:Frequency} = MIT_from


"""
fconvert(F_to::Type{<:Union{<:CalendarFrequency,<:YPFrequency}}, MIT_from::MIT{<:Union{<:CalendarFrequency,<:YPFrequency}}; values_base = :end, round_to=:current)

Converts a MIT instance to the given target frequency.

`values_base` determines the position within the input frequency to align with the output frequency. The options are `:begin`, `:end`. The default is `:end`.
`round_to` is only when converting to BDaily MIT, it determines the direction in which to find the nearest business day. The options are `:previous`, `:next`, and `:current`. The default is `:previous`.
When converting to BDaily MIT the conversion will result in an error if round_to == `:current` and the date at the start/end of the provided input is in a weekend.


For example, 
fconvert(Quarterly, 22Y, values_base=:end) ==> 2022Q4
fconvert(Quarterly, 22Y, values_base=:begin) ==> 2022Q1
"""

# MIT YP => YP
# having these different signatures significantly speeds up the performance; from a few microseconds to a few nanoseconds
fconvert(F_to::Type{<:Union{<:YPFrequency}}, MIT_from::MIT{<:Union{<:YPFrequency}}; values_base=:end, round_to=:current) = _fconvert(F_to, MIT_from, values_base=values_base,skip_parameter=false, round_to=round_to)
fconvert(F_to::Type{<:Union{<:YPFrequency}}, MIT_from::MIT{Yearly}; values_base=:end, round_to=:current) = _fconvert(F_to, MIT_from, values_base=values_base, skip_parameter=true, round_to=round_to)
fconvert(F_to::Type{<:Union{<:YPFrequency}}, MIT_from::MIT{Quarterly}; values_base=:end, round_to=:current) = _fconvert(F_to, MIT_from, values_base=values_base, skip_parameter=true, round_to=round_to)
fconvert(F_to::Type{<:Union{<:YPFrequency}}, MIT_from::MIT{Monthly}; values_base=:end, round_to=:current) = _fconvert(F_to, MIT_from, values_base=values_base, skip_parameter=true, round_to=round_to)
function _fconvert(F_to::Type{<:Union{<:YPFrequency}}, MIT_from::MIT{<:Union{<:YPFrequency}}; values_base=:end, skip_parameter=false, round_to=:current)
    F_from = frequencyof(MIT_from)
    values_base_adjust = values_base == :end ? 1 : 0
    rounder = values_base == :end ? ceil : floor
    from_month = Int(MIT_from+values_base_adjust) * 12 / ppy(F_from) - values_base_adjust
    if !skip_parameter 
        from_month -= (12 / ppy(F_from)) - getproperty(F_from, :parameters)[1]
    end
    out_period = (from_month + values_base_adjust) / (12 / ppy(F_to)) - values_base_adjust
    return MIT{F_to}(rounder(Integer, out_period))
end

# MIT Calendar => YP + Weekly
function fconvert(F_to::Type{<:Union{<:YPFrequency,<:Weekly}}, MIT_from::MIT{<:Union{<:CalendarFrequency}}; values_base=:end, round_to=:current)
    if values_base == :end
        return _get_out_indices(F_to, [Dates.Date(MIT_from, :end)])[begin]
    elseif values_base == :begin
        return _get_out_indices(F_to, [Dates.Date(MIT_from, :begin)])[begin]
    end

    # error checking
    throw(ArgumentError("values_base argument must be :begin or :end. Received: $(values_base)."))
end

# MIT => BDaily
# function fconvert(F_to::Type{BDaily}, MIT_from::MIT{<:Union{<:Weekly,<:YPFrequency,Daily}}; values_base=:end)
    
# end
function fconvert(F_to::Type{BDaily}, MIT_from::MIT{<:Union{<:Weekly,<:YPFrequency,Daily}}; values_base=:end, round_to=:previous)
    if round_to == :previous
        return bdaily(Dates.Date(MIT_from, values_base))
    elseif round_to == :next
        return bdaily(Dates.Date(MIT_from, values_base); bias_previous=false)
    elseif round_to == :current
        d = Dates.Date(MIT_from)
        if (dayofweek(d) >= 6)
            throw(ArgumentError("$d is on a weekend. Pass round_to = :previous or :next to convert to $F_to"))
        end
        return bdaily(d)
    else
        throw(ArgumentError("round_to argument must be :current, :previous, or :next. Received: $(round_to)."))
    end
end

# MIT => Daily
fconvert(F_to::Type{Daily}, MIT_from::MIT{<:Union{<:Weekly,<:YPFrequency}}, values_base=:end, round_to=:current) = daily(Dates.Date(MIT_from, values_base))
function fconvert(F_to::Type{<:Daily}, MIT_from::MIT{BDaily}, values_base=:end, round_to=:current)
    mod = Int(MIT_from) % 5
    if mod == 0
        mod = 5
    end
    return MIT{F_to}(Int(floor((Int(MIT_from) - 1) / 5) * 7 + mod))
end


"""
_fconvert_parts(F_to::Type{<:Union{<:YPFrequency}}, MIT_from::MIT{<:Union{<:YPFrequency}}; values_base=:end, check_parameter_from=false, check_parameter_to=false)

This is a helper function used when converting TSeries or MIT UnitRanges between YPfrequencies. It provides the necessary component parts to make decisions about the completeness
    of the input tseries relative to the output frequency.
"""
# having these different signatures significantly speeds up the performance; from a few microseconds to a few nanoseconds
fconvert_parts(F_to::Type{<:Union{<:YPFrequency}}, MIT_from::MIT{<:Union{<:YPFrequency}}; values_base=:end) = _fconvert_parts(F_to, MIT_from, values_base=values_base)
fconvert_parts(F_to::Type{<:Union{Quarterly{N},Yearly{N}}}, MIT_from::MIT{<:Union{<:YPFrequency}}; values_base=:end) where N = _fconvert_parts(F_to, MIT_from, values_base=values_base, check_parameter_to=true)
fconvert_parts(F_to::Type{<:Union{Quarterly{N1},Yearly{N1}}}, MIT_from::MIT{<:Union{Quarterly{N2},Yearly{N2}}}; values_base=:end) where {N1, N2} = _fconvert_parts(F_to, MIT_from, values_base=values_base, check_parameter_to=true, check_parameter_from=true)
fconvert_parts(F_to::Type{<:Union{<:YPFrequency}}, MIT_from::MIT{<:Union{Quarterly{N},Yearly{N}}}; values_base=:end) where N = _fconvert_parts(F_to, MIT_from, values_base=values_base, check_parameter_from=true)
function _fconvert_parts(F_to::Type{<:Union{<:YPFrequency}}, MIT_from::MIT{<:Union{<:YPFrequency}}; values_base=:end, check_parameter_from=false, check_parameter_to=false)
    F_from = frequencyof(MIT_from)
    mpp_from = div( 12, ppy(F_from))
    mpp_to = div( 12, ppy(F_to))

    from_month_adjustment = 0
    if check_parameter_from 
        from_month_adjustment -= mpp_from - getproperty(F_from, :parameters)[1]
    end

    to_month_adjustment = 0
    if check_parameter_to 
        to_month_adjustment -= mpp_to - getproperty(F_to, :parameters)[1]
    end
    
    if values_base == :begin
        from_start_month = Int(MIT_from) * mpp_from + 1 + from_month_adjustment
        to_period, rem = divrem(from_start_month - to_month_adjustment - 1,  mpp_to)
        to_start_month = to_period * mpp_to + 1 + to_month_adjustment
        return to_period, from_start_month, to_start_month
    elseif values_base == :end
        from_end_month = (Int(MIT_from) + 1) * mpp_from + from_month_adjustment
        to_period, rem = divrem(from_end_month - to_month_adjustment - 1,  mpp_to)
        to_end_month = (to_period + 1) * mpp_to + to_month_adjustment
        return to_period, from_end_month, to_end_month
    end
end



######################
#     UNITRANGE
######################
"""
    fconvert(F_to, range_from::UnitRange{MIT})

Convert the time MIT `MIT_from` to the desired frequency `F_to`.
"""
fconvert(F_to::Type{<:Frequency}, range_from::UnitRange{MIT}; args...) = error("""
Conversion of MIT UnitRange from $(frequencyof(range_from)) to $F_to not implemented.
""")

# do nothing when the source and target frequencies are the same.
fconvert(F_to::Type{F}, range_from::UnitRange{MIT{F}}) where {F<:Frequency} = range_from

"""
fconvert(F_to::Type{<:Union{<:CalendarFrequency,<:YPFrequency}}, MIT_from::MIT{<:Union{<:CalendarFrequency,<:YPFrequency}}; trim=:both)

Converts a MIT UnitRange to the given target frequency.

`trim` determines whether to truncate the beginning/end of the output range whenever the input range begins / ends partway through an MIT
in the output frequency. The options are `:begin`, `:end`, and `:both`. The default is `:both`.

For example, 
fconvert(Quarterly, 2022Y:2024Y) ==> 2022Q1:2024Q4
fconvert(Quarterly, 2022M2:2022M7, trim=:begin) => 2022Q2:2022Q3
fconvert(Quarterly, 2022M2:2022M7, trim=:end) => 2022Q1:2022Q2
fconvert(Quarterly, 2022M2:2022M7, trim=:both) => 2022Q2:2022Q2
"""
# MIT range: YP => YP
# having these different signatures significantly speeds up the performance; from a few microseconds to a few nanoseconds 
fconvert(F_to::Type{<:Union{<:YPFrequency}}, range_from::UnitRange{<:MIT{<:Union{<:YPFrequency}}}; trim=:both, parts=false) = _fconvert(F_to, range_from, trim=trim, parts=parts)
fconvert(F_to::Type{<:Union{Quarterly{N},Yearly{N}}}, range_from::UnitRange{<:MIT{<:Union{<:YPFrequency}}}; trim=:both, parts=false) where N = _fconvert(F_to, range_from, trim=trim, parts=parts, check_parameter_to=true)
fconvert(F_to::Type{<:Union{Quarterly{N1},Yearly{N1}}}, range_from::UnitRange{<:MIT{<:Union{Quarterly{N2},Yearly{N2}}}}; trim=:both, parts=false) where {N1, N2} = _fconvert(F_to, range_from, trim=trim, parts=parts, check_parameter_to=true, check_parameter_from=true)
fconvert(F_to::Type{<:Union{<:YPFrequency}}, range_from::UnitRange{<:MIT{<:Union{Quarterly{N},Yearly{N}}}}; trim=:both, parts=false) where N = _fconvert(F_to, range_from, trim=trim, parts=parts, check_parameter_from=true)
function _fconvert(F_to::Type{<:Union{<:YPFrequency}}, range_from::UnitRange{<:MIT{<:Union{<:YPFrequency}}}; trim=:both, parts=false, check_parameter_from=false, check_parameter_to=false)
    fi_to_period, fi_from_start_month, fi_to_start_month = _fconvert_parts(F_to, first(range_from), values_base=:begin, check_parameter_from=check_parameter_from, check_parameter_to = check_parameter_to)
    li_to_period, li_from_end_month, li_to_end_month = _fconvert_parts(F_to, last(range_from), values_base=:end, check_parameter_from=check_parameter_from, check_parameter_to = check_parameter_to)
    
    if parts
        return fi_to_period, fi_from_start_month, fi_to_start_month, li_to_period, li_from_end_month, li_to_end_month
    end

    trunc_start = trim !== :end && fi_to_start_month < fi_from_start_month ? 1 : 0
    trunc_end = trim !== :begin && li_to_end_month > li_from_end_month ? 1 : 0
    fi = MIT{F_to}(fi_to_period+trunc_start)
    li = MIT{F_to}(li_to_period-trunc_end)
    
    return fi:li
end


# range: YP + Calendar => YP + Weekly (excl. YP => YP)
fconvert(F_to::Type{<:Union{<:YPFrequency,<:Weekly}}, range_from::UnitRange{<:MIT{<:Union{<:CalendarFrequency}}}; trim=:both, errors=true) = _fconvert_using_dates(F_to, range_from, trim=trim, errors=errors)
fconvert(F_to::Type{<:Union{<:Weekly}}, range_from::UnitRange{<:MIT{<:Union{<:YPFrequency}}}; trim=:both, errors=true) = _fconvert_using_dates(F_to, range_from, trim=trim, errors=errors)
function _fconvert_using_dates(F_to::Type{<:Union{<:YPFrequency,<:Weekly}}, range_from::UnitRange{<:MIT{<:Union{<:CalendarFrequency, <:YPFrequency}}}; trim=:both, errors=true)
    fi, li, trunc_start, trunc_end = _fconvert_using_dates_parts(F_to, range_from, trim=trim, errors=errors)
    return fi+trunc_start:li-trunc_end
end


# MITRange => Daily
fconvert(F_to::Type{Daily}, range_from::UnitRange{<:MIT{<:Union{<:Weekly,Daily,<:YPFrequency}}}) = daily(Dates.Date(range_from[begin] - 1) + Day(1)):daily(Dates.Date(range_from[end]))
fconvert(F_to::Type{<:Daily}, range_from::UnitRange{MIT{BDaily}}) = daily(Dates.Date(range_from[begin])):daily(Dates.Date(range_from[end]))

# MITRange => BDaily
fconvert(F_to::Type{BDaily}, range_from::UnitRange{<:MIT{<:Union{<:CalendarFrequency,<:YPFrequency}}}) = bdaily(Dates.Date(range_from[begin] - 1) + Day(1), bias_previous=false):bdaily(Dates.Date(range_from[end]))

# MIT range: YP + Calendar => YP + Weekly
function _fconvert_using_dates_parts(F_to::Type{<:Union{<:YPFrequency,<:Weekly}}, range_from::UnitRange{<:MIT{<:Union{<:CalendarFrequency, <:YPFrequency}}}; trim=:both, errors=true)
    errors && _validate_fconvert_yp(F_to, frequencyof(first(range_from)))
    if errors && trim ∉ (:both, :begin, :end)
        throw(ArgumentError("trim argument must be :both, :begin, or :end. Received: $(trim)."))
    end
    F_from = frequencyof(range_from)
    if F_to > F_from
        if F_from <: BDaily
            dates = [Dates.Date(range_from[begin]), Dates.Date(range_from[end])]
            if get_option(:bdaily_skip_holidays)
                holidays_map = get_option(:bdaily_holidays_map)
                dates = dates[holidays_map[rng_from].values]
            end
        else
            dates = [Dates.Date(range_from[begin] - 1) + Day(1), Dates.Date(range_from[end])]
        end
        out_index = _get_out_indices(F_to, dates)
        fi = out_index[1]
        trunc_start = 0
        # truncate the start if the first output period does not start within the first input period
        if trim !== :end && fconvert(F_from, fi, values_base=:begin) != range_from[begin] 
            trunc_start = 1
        end
        
        li = out_index[end]
        trunc_end = 0
        # truncate the end if the last output period ends in an input period beyond the last
        if trim !== :begin && fconvert(F_from,li, values_base=:end) != range_from[end]
            trunc_end = 1
        end
        return fi, li, trunc_start, trunc_end
    else # F_to <= F_from
        if F_from <: BDaily
            if get_option(:bdaily_skip_holidays)
                holidays_map = get_option(:bdaily_holidays_map)
                padded_dates = padded_dates[holidays_map[rng_from].values]
                # find the nearest non-holidays to see if they are in a different output period
                pad_start_date = first(rng_from) - 1
                while holidays_map[proposed_pad_start_date] == 0
                    pad_start_date = pad_start_date - 1
                end
                pad_end_date = last(rng_from) + 1
                while holidays_map[pad_end_date] == 0
                    pad_end_date = pad_end_date + 1
                end
                padded_dates = [pad_start_date, padded_dates..., pad_end_date]
            else
                padded_dates = [Dates.Date(range_from[begin] - 1), Dates.Date(range_from[begin]), Dates.Date(range_from[end]), Dates.Date(range_from[end] + 1)]
            end
        else
            if F_to > F_from
                padded_dates = [Dates.Date(range_from[begin] - 1, :begin), Dates.Date(range_from[begin], :begin), Dates.Date(range_from[end]), Dates.Date(range_from[end] + 1)]
            else
                padded_dates = [Dates.Date(range_from[begin] - 1), Dates.Date(range_from[begin]), Dates.Date(range_from[end]), Dates.Date(range_from[end] + 1)]
            end
        end
        out_index = _get_out_indices(F_to, padded_dates)
        
        # if the first default and padded output periods are the same, then we do not have
        # the whole of the first output period
        fi = out_index[2]
        trunc_start = 0
        # truncate the start if the padded output period is the same as the first output period
        # in this case we do not have the whole of the first output period in the inputs
        if trim !== :end && out_index[1] == out_index[2]
            trunc_start = 1
        end
        li = out_index[end-1]
        trunc_end = 0
        # truncate the end if the padded end period is the same as the last output period
        # in this case we do not have the whole of the last period in the inputs
        if trim !== :begin && out_index[end] == out_index[end-1]
            trunc_end = 1
        end
        return fi, li, trunc_start, trunc_end
    end
end


# function _fconvert_using_dates_parts(F_to::Type{<:Union{<:YPFrequency,<:Weekly}}, range_from::UnitRange{<:MIT{<:Union{<:CalendarFrequency, <:YPFrequency}}}; trim=:both, errors=true)
#     errors && _validate_fconvert_yp(F_to, frequencyof(first(range_from)))
#     if errors && trim ∉ (:both, :begin, :end)
#         throw(ArgumentError("trim argument must be :both, :begin, or :end. Received: $(trim)."))
#     end
#     F_from = frequencyof(range_from)
#     if F_to > F_from
#         if F_from <: BDaily
#             dates = [Dates.Date(range_from[begin]), Dates.Date(range_from[end])]
#             if get_option(:bdaily_skip_holidays)
#                 holidays_map = get_option(:bdaily_holidays_map)
#                 dates = dates[holidays_map[rng_from].values]
#             end
#         else
#             dates = [Dates.Date(range_from[begin] - 1) + Day(1), Dates.Date(range_from[end])]
#         end
#         out_index = _get_out_indices(F_to, dates)
#         fi = out_index[1]
#         # trunc_start = fconvert(F_from, fi, values_base=:begin) == fconvert(F_from, fi - 1, values_base=:begin) ? 1 : 0
#         trunc_start = fconvert(F_from, fi, values_base=:begin) == fconvert(F_from, fi - 1, values_base=:begin) ? 1 : 0
#         if trim == :end
#             trunc_start = 0
#         end
#         li = out_index[end]
#         trunc_end =  fconvert(F_from,li, values_base=:end) == fconvert(F_from, li + 1, values_base=:end) ? 1 : 0
#         if trim == :begin
#             trunc_end = 0
#         end
#         return fi, li, trunc_start, trunc_end
#     end
   
#     if F_from <: BDaily
#         if get_option(:bdaily_skip_holidays)
#             holidays_map = get_option(:bdaily_holidays_map)
#             padded_dates = padded_dates[holidays_map[rng_from].values]
#             # find the nearest non-holidays to see if they are in a different output period
#             pad_start_date = first(rng_from) - 1
#             while holidays_map[proposed_pad_start_date] == 0
#                 pad_start_date = pad_start_date - 1
#             end
#             pad_end_date = last(rng_from) + 1
#             while holidays_map[pad_end_date] == 0
#                 pad_end_date = pad_end_date + 1
#             end
#             padded_dates = [pad_start_date, padded_dates..., pad_end_date]
#         else
#             padded_dates = [Dates.Date(range_from[begin] - 1), Dates.Date(range_from[begin]), Dates.Date(range_from[end]), Dates.Date(range_from[end] + 1)]
#         end
#     else
#         if F_to > F_from
#             padded_dates = [Dates.Date(range_from[begin] - 1, :begin), Dates.Date(range_from[begin], :begin), Dates.Date(range_from[end]), Dates.Date(range_from[end] + 1)]
#         else
#             padded_dates = [Dates.Date(range_from[begin] - 1), Dates.Date(range_from[begin]), Dates.Date(range_from[end]), Dates.Date(range_from[end] + 1)]
#         end
#     end
#     out_index = _get_out_indices(F_to, padded_dates)
    
#     # include_weekends = frequencyof(range_from) <: BDaily
#     # trunc_start, trunc_end = _get_fconvert_truncations(F_to, frequencyof(range_from), dates, trim, include_weekends=include_weekends, shift_input=false, pad_input=false)

#     fi = out_index[2]
#     trunc_start = out_index[1] == out_index[2] ? 1 : 0
#     if trim == :end
#         trunc_start = 0
#     end
#     # if the default and padded output periods are the same, then we do not have
#     # the whole of the last output period
#     li = out_index[end-1]
#     trunc_end = out_index[end] == out_index[end-1] ? 1 : 0
#     if trim == :begin
#         trunc_end = 0
#     end
#     return fi, li, trunc_start, trunc_end
#     # return out_index[begin]+trunc_start:out_index[end]-trunc_end
# end

# function _fconvert(F_to::Type{<:Union{<:YPFrequency}}, MIT_from::MIT{<:Union{<:YPFrequency}}; values_base=:end, remainder=false, skip_parameter=false)
#     F_from = frequencyof(MIT_from)
#     values_base_adjust = values_base == :end ? 1 : 0
#     rounder = values_base == :end ? ceil : floor
#     from_month = Int(MIT_from+values_base_adjust) * 12 / ppy(F_from) - values_base_adjust
#     if !skip_parameter 
#         from_month -= (12 / ppy(F_from)) - getproperty(F_from, :parameters)[1]
#     end
#     out_period = (from_month + values_base_adjust) / (12 / ppy(F_to)) - values_base_adjust
#     if remainder
#         return MIT{F_to}(rounder(Integer, out_period)), out_period
#     end
#     return MIT{F_to}(rounder(Integer, out_period))
# end