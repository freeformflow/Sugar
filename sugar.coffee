###
================================================================================
Sugar is a parser-combinator library that adds kick-ass functionality to CoffeeScript.
CoffeeScript is already easier to write and maintain than hand-written JavaScript.
Sugar takes it to the next level and makes it execute faster.  So, what's not to like?
Take your CoffeeScript with a spoonful of Sugar.

The goal is to retain CoffeeScript's grace while allowing it access to another
translation target.  Sugar targets Low-Level JavaScript (LLJS), an experimental
JavaScript variant that self-describes as the "bastard child of JavaScript and C".

LLJS produces valid JavaScript, but nothing that you would want to write by
hand.  LLJS produces asm.js style code that runs fast.  With static type coercion
and better memory management, the JavaScript that LLJS produces doesn't need
time-consuming garbage collection, and it can be better optimized by Just-In-Time
compilers that are standard in modern browsers.  You can even target experiemntal
Ahead-Of-Time compilers if you fully conform to the asm.js style.


- Sugar is a technology developed by PandaStrike.  http://www.pandastrike.com
- LLJS Project Homepage:  http://mbebenita.github.io/LLJS/

To Do List:
(0) Port of CoffeeScript Translator
(1) Statically typed variables
(2) Pointers
(3) Structs
(4) Unions
(5) Typed functions
(6) Malloc & Free
================================================================================
###

# So, let's get started.  Parser-combinators work by leveraging the power of
# regular expressions.  We define "parts of speech" for a language [things like
# operator, symbol, string, etc.].  We create a parser for each one that examines
# the input looking for a particular regular expression.
#
# Now, these "parts of speech" parsers pretty low-level.  They are not useful by
# themselves, but we can daisy chain them together.  This is the combinator part
# of Sugar.  We create more parsers that can call the low level parsers, looking
# for patterns.  This way we turn "parts of speech" into "grammar".  We keep
# building higher and higher level parsers until we can call a single parser to
# kickstart a translation of the entire codebase.

# Parsers always follow the same basic form.  They either take an input, or are
# called with the "do" keyword.  Inside every parser, we call a generic function
# that is passed the original, unconsumed code as a string.  The parser performs
# some sort of test on the string and returns true or false.  In addition, the
# parser must also return any portion of the string that remains unconsumed.
# Other parsers will attempt to process this section.



# To make everything easier, we create a result object that holds the true-false
# match condition and remaining portion of the string to be processed.  Every
# time we return a parser result, we need to pass both to this object.

result = (match, rest) -> {match, rest}

#===============================================================================
# Regular Expressions - # This simple function is the root of Sugar.  This
# regular expression parser will be called by many low level parsers directly
# examining the code.
#===============================================================================
RegularExpression = (regex) ->

  (input) ->
    hit = input.match(regex)

    if hit
      # We found what we were looking for.  Fill out the "result" object.
      return result hit[0], input[ hit[0].length.. ]
    else
      # Didn't find what we were looking for.  Return empty object.
      return {}



#===============================================================================
# Blocks - These are the building blocks.  Each one will call upon the
# above "RegularExpression" function to match patterns in the input string.
#===============================================================================
WhiteSpace = do ->
  # This will search for any whitespace, plain and simple.

  search = RegularExpression ///^(  # Searches restricted to the begining of the input string
                            \s*     # zero or more whitespace character(s).
                            )///

  (input) ->

    {match, rest} = search (input)

    if match?
      # We found what we were looking for.  Fill out the "result" object.
      return result { type:"WhiteSpace", name: match}, rest
    else
      # Didn't find what we were looking for.  Return empty object.
      return {}



ArithmeticOperator = do ->
  # This will search for operators related to basic math.

  search = RegularExpression ///^(
            \+ | \- | \* | \/ | =  # single +, -, *, /, or = character.
                              )///

  (input) ->

    {match, rest} = search (input)

    if match?
      # We found what we were looking for.  Fill out the "result" object.
      return result {type:"Operator", operator: match}, rest
    else
      # Didn't find what we were looking for.  Return empty object.
      return {}



ComparisonOperator = do ->
  # This will search for operators that deal with comparisons.

  search = RegularExpression ///^(   # Searches restricted to the begining of the input string
          == | < | > | <= | >= | !=  # single ==, <, >, <=, >=, or != character(s).
                             )///

  (input) ->

    {match, rest} = search (input)

    if match?
      # We found what we were looking for.  Fill out the "result" object.
      return result {type:"Operator", operator: match}, rest
    else
      # Didn't find what we were looking for.  Return empty object.
      return {}


LogicOperator = do ->
  # This will search for operators that deal with logic.

  search = RegularExpression ///^(   # Searches restricted to the begining of the input string
                          or | and   # "or" or "and" operator.
                             )///

  (input) ->

    {match, rest} = search (input)

    if match?
      # We found what we were looking for.  Fill out the "result" object.
      return result {type:"Operator", operator: match}, rest
    else
      # Didn't find what we were looking for.  Return empty object.
      return {}


UnitaryOperator = do ->
  # This will search for operators that iterate variable value.

  search = RegularExpression ///^(   # Searches restricted to the begining of the input string
                        \+\+ | --    # ++ or -- iterative operator.
                             )///

  (input) ->

    {match, rest} = search (input)

    if match?
      # We found what we were looking for.  Fill out the "result" object.
      return result {type:"Operator", operator: match}, rest
    else
      # Didn't find what we were looking for.  Return empty object.
      return {}




Symbol = do ->
  # The catch-all.  This will search for any chunk of characters that are not whitespace, an
  # operator, a string, a reserved word, or whatever...

  search = RegularExpression ///^(   # Searches restricted to the begining of the input string
      [ \w \. \( \) \{ \} \[ \] ]+   # one or more of [A-Z], [a-z], [0-9], _, or ., (, ), {, }, [, ] character.
                            )///

  (input) ->

    {match, rest} = search (input)

    if match?
      # We found what we were looking for.  Fill out the "result" object.
      return result {type:"Symbol", name: match}, rest
    else
      # Didn't find what we were looking for.  Return empty object.
      return {}


String = do ->
  # This is slightly more advanced.  For strings, we need to detect closure, which
  # is a little annoying.  We'll need to start by figuring out if we're dealing
  # with double or single quote.  Afterward, we have to scoop up all the characters
  # inside the quote, ignoring their normal functions.  We continue until we find
  # another single/double quote to finish off this string.

  search = RegularExpression ///^(   # Searches restricted to the begining of the input string
                          ' | "      # one ' or " character.
                            )///

  (input) ->

    {match, rest} = search (input)

    if match?
      # We found the first quote.  We may continue
      temp = match     # Temporary string to hold opening character.

      if match == "\""
        search = RegularExpression ///^(   # Searches restricted to the begining of the input string
                      [\w \s \. \n \']*    # Zero or more of characters: [A-Z],[a-z],[0-9], _, ., newline, or '
                                )///

      else
        search = RegularExpression ///^(   # Searches restricted to the begining of the input string
                      [\w \s \. \n \"]*    # Zero or more of characters: [A-Z],[a-z],[0-9], _, ., newline, or "
                                )///

      # Continue searching.
      input = rest
      {match, rest} = search (input)

      if match?
        # We have the text of the string.  Append the start and end quotes.  Don't forget to
        # adjust the unconsumed string to pick up that dangling quotation mark.
        match = temp + match + temp
        rest = rest[1..]

        # Fill out the "result" object and return
        result {type: "String", value: match},  rest
      else
          # Didn't find what we were looking for.  Return empty object.
          # This would actually be bad.  Come put error handling here.
          return {}


    else
        # Didn't find what we were looking for.  Return empty object.
        return {}



#===============================================================================
# Rules - We're done making the building blocks.  Now we start chaining them
# together.  The following prototype "rule" does just that.  It take a list of
# building blocks and calls those functions in sequence, parsing the code.
#===============================================================================


PrototypeRule = (block_chain..., action) ->
  # This is the prototype rule.  Every rule will call this function, take a list of
  # building blocks (block_chain) and try to match a pattern.  This pattern is
  # higher level than before.  While we still pass these rules raw text, it
  # is really just passed to the lower-level parsers.  We are looking for patterns
  # with intelligence, beyond what a regular expression matcher could find by itself.

  (input) ->

    # This array holds the series of grouped characters from the original string.
    # They will be utilized by the "action" passed to this rule.
    tokens = []

    # Eack low-level block consumes part of the original string.  If the rule fails
    # we need to restore the string so we can try another rule.  Therefore, until the
    # rule completes successsfully, input must be copied into a temporary string
    # to be modified.  Once the rule passes, the changes are made permanent.
    string_buffer = input

    # Iterate through the commands in this rule.
    while block_chain.length > 0
      block = block_chain.shift()

      # See if we get a pattern match
      {match, rest} = block string_buffer

      if match?
        # We found what we were looking for.  Add this result to tokens.
        tokens.push match unless match is true

        # Continue to the next block.
        string_buffer = rest
      else
        # Didn't find what we were looking for.  Return a failure for this whole rule.  Restore input.
        return result false, input


    # If we have escaped the while loop, we have successfully parsed the original
    # string using the blocks stipulated.  It's time to utlize the specified action on tokens.
    action tokens


    # Return a success...  We must make the temporary changes stored in string_buffer permanent.
    return result true, rest



#===============================================================================
# Meta-Rule Modifiers = Now we're getting crazy.  Even though we can define
# rules, it's still not enough.  We need to be able to string rules
# together or provide option branching. These modifiers are the source of a
# parser-combinator's power.
#===============================================================================

# =======
# Atomic
# =======
# Meta_Until = (block_chain...) ->
#   # This meta-rule will try all the blocks passed to it until one returns true.
#   # Once that happens, it keeps that answer and returns true.
#
#   (input) ->
#     while input.length > 0 and chunk_chain.length > 0
#       block = block_chain.shift()
#
#       {match, rest} = block input
#
#       if match?
#         # We have a winner.  Return the result object.
#         return result match, rest
#       else
#         # We didn't find what we were looking for.  Keep going.
#         continue
#
#     # If we've made it out of the loop without a match, none of the blocks match.  Return failure.
#     return {}


Meta_Many = (block_chain...) ->
  # This meta-rule will try all the blocks passed to it until one returns false.
  # Once that happens, all previous results that have passed are returned.  It's for
  # when you need to try multiple blocks, but not all need to pass.

  collection = []

  (input) ->
    while input.length > 0 and chunk_chain.length > 0
      block = block_chain.shift()

      {match, rest} = block input

      if match?
        # Successful.  Collect the result. Update the input. Keep going.
        collection.push match
        input = rest
        continue
      else
        # Failure.  Return all successful results.
        return result collection, input

    # If we've made it out of the loop, all of the blocks match.  Return complete list.
    return result collection, rest



# =======
# Generator -
# Generators are operators that have a signature of F(R) => R, taking a given
# rule and returning another rule, such as ignore, which parses a given rule and
# throws away the result.

# Generator operators are converted (via Meta_Multi) into functions that
# can also take a list or array of rules and return an array of new rules as
# though the function had been called on each rule in turn (which is what actually happens).

# This converts generators into de facto vectors, allowing easier mixing with vectors.
# =======


Meta_Optional = (block) ->
  # This meta-rule will try the block passed to it. Even if it fails,
  # this funtion still returns true.  If it fails, it returns the input string.

  (input) ->
    while input.length > 0

      {match, rest} = block input

      if match?
        # Successful.  Return the result.
        return result match, rest
      else
        # Failure.  Return true and the input string.
        return result true, input



Meta_Not = (block) ->
  # This meta-rule will try the block passed to it. If it passes
  # the meta-rule returns false.  Bizzaro-World logic reigns.

  (input) ->
    while input.length > 0

      {match, rest} = block input

      if match?
        # Successful.  Which in Bizzaro-World means it fails.  Return failure.
        return {}
      else
        # Failure.  Which in Bizzaro-World means it succeeds.
        return result true, input


Meta_Ignore = (block) ->
  # This meta-rule will try the block passed to it. Regardless of whether the
  # block passes or not, the meta-rule passes "true".  The importatnt thing is
  # that this returns an updated string of unconsumed input, it just doesn't do
  # anything with it.

  (input) ->
    while input.length > 0

      {match, rest} = block input

      if match?
        # Successful.  Return true result with new string.
        return result true, rest
      else
        # Failure.  Return true result with old string.
        return result true, input


# Product ->  wft??

Meta_Cache = (block) ->
  # This meta-rule will try all the blocks passed to it. Regardless of whether the
  # block passes or not, the meta-rule stores the result.  This is important, because
  # if we are repeatedly attempting to parse a section with slightly different
  # rules, we don't have to re-parse sections that are the same.  This saves us
  # time because it reduces a convoluted caluclation into a lookup.

  (input) ->
    while input.length > 0

      if cache?
        {match, rest} = cache
      else
        {match, rest} = block input

      if match?
        # Successful.  Return result object.
        cache = {match, rest}
        return result match, rest
      else
        # Failure.  Cache fail. Return fail.
        cache = {false, input}
        return result false, input


# =======
# Vector -
# Vector operators are those that have a signature of F(R1,R2,...) => R, take a
# list of rules and returning a new rule, such as each.
# =======

###
Meta_Multi = (meta_rule, block_chain...) ->
  # This meta-rule will accept a meta-rule followed by a chain of blocks for processing.
  # This function processes them all, and will faithfully return the parsing outcome,
  # even if it's false.  This allows combination with vectors.

  (input) ->
    while input.length > 0 and block_chain.length > 0
      block = block_chain.shift()

      search = meta_rule block
###

Meta_Any = (block_chain...) ->
  # Logical OR.  This meta-rule will try all the blocks passed to it until one returns true.
  # Once that happens, it returns that result.

  (input) ->
    while input.length > 0 and chunk_chain.length > 0
      block = block_chain.shift()

      {match, rest} = block input

      if match?
        # Successful.  Return result object
        return result match, rest
      else
        # Failure.  Keep going.
        continue

    # If we've made it out of the loop, none of the blocks passed. Return failure.
    return result false, input


Meta_Each = (block_chain...) ->
  # Logical AND.   This meta-rule will try all the blocks passed to it until one returns false.
  # Once that happens, it returns failure.  If it makes it through the whole list,
  # it returns a list of results.

  collection = []

  (input) ->
    while input.length > 0 and chunk_chain.length > 0
      block = block_chain.shift()

      {match, rest} = block input

      if match?
        # Successful.  Collect results. Keep going.
        collection.push match
        continue
      else
        # Failure.  Return failure.
        return result false, input

    # If we've made it out of the loop, all of the blocks passed. Return results.
    return result collection, rest

Meta_All = (block_chain...) ->
  # This meta-rule is based off of Meta_Each. All blocks will be tried, but they are all
  # considered Meta_Optional.  Successes will take effect and failures will be ingored.

  Meta_Each Meta_Otional block_chain...


# =======
# Delimited
# =======
Sequence = (field, delimiter) ->
  # This meta-rule will chain together symbols that are delimited.  The most common example
  # will be symbols delimited by commas in a function statement.  The function accepts
  # (block, regular_expression) as its arguments.

  collection = []

  (input) ->
    while input.length > 0

      {match, rest} = field input

      if match?
        # We have a match for the field.  Check for delimiter.
        search = RegularExpression delimiter
        {match, rest} = search rest

        if match?
          # We found a delimiter.  Keep going.
          collection.push match
          input = rest
          continue
        else
          # There is no delimiter.  Exit loop.
          break

      else
        # We have not found what we are looking for.  Exit loop.
        break

    # We have exited the loop.  Return what we found and fail if we found nothing.
    if collection.length == 0
      return {}
    else
      return result collection, rest


# =========
# Composite - These are helpers that join other meta-rules together to leverage more power.
# =========
Meta_Between = (before, field, after) ->
  # This helper function checks that a field of interest is between two other blocks.
  # These blocks's presence is Meta_Optional.

  search = Meta_Each Meta_Optional(before), field, Meta_Optional(after)

  (input) ->
    while input.length > 0

      {match, rest} = search input

      if match?
        # Successful.  Return the result.
        return result match, rest
      else
        # Failure.  Return failure
        return {}



Meta_Set = (block_chain..) ->
  # This helper function allows you to search for a collection of blocks.  Every block
  # must be present, but their order is unimportant.  For example, if we have five blocks
  # to deal with, that's 120 combinations.  We would prefer to cover this with one rule.

  collection = []

  # Start by creating a copy of all the blocks.  This will be our working copy.
  working_copy = []
  working_copy.push(block) for block in block_chain

  (input) ->

    # First, check to make sure we are dealing with more than one block.  If there
    # is just one, we don't have to do that much work.
    if working_copy.length == 1

      {match, rest} = working_copy[0] input

      if match?
        # Success.  Return result object.
        return result match, rest
      else
        # Failure.  Return failure.
        return {}

    else
      finished = false

    # We must recursively search for matching blocks.  If we find a match, we delete
    # that block from block_chain, which means we have less to search for in the next iteration.

    while finished == false
      for i in [0..working_copy.length]

        {match, rest} = working_copy[i] input

        if match?
          # We found a block that matches.
          if working_copy.length == 1
            # Success.  We're done.  Return the result object.
            collection.push match
            return result collection, rest
          else
            # Delete this block from the chain and start over.
            working_copy.splice i, 1
            collection.push match
            input = rest
            break
        else
          # We didn't find what we were looking for.  Keep going.
          continue

      # If we have exited the for-loop, the input doesn't contain what's needed.  Return failure.
      return {}



# list....

# forward...


# =======
# Translation
# =======
# replace
# process
# min
