# Math Blitz — road to an 800 on SAT Math

Rules for the daily lesson writer:
- One topic per day, in order. Each video teaches ONE idea in 45–75 seconds, then asks ONE multiple-choice question (4 choices; wrong choices are the classic mistakes).
- Every 7th day (days 7, 14, 21, …) is a **Boss Battle**: no new topic. A harder mixed question that combines the last week's topics.
- If he missed yesterday's question, or didn't answer it, the next video re-teaches that topic from a new angle ("Instant Replay") before moving on. Two misses in a row on the same topic → slow down: split it into smaller steps.
- If he gets 5 in a row right, start using harder, SAT-style wording for that unit.
- Questions get closer to real SAT style as the units go on (word problems, "which of the following", grid-in style answers given as choices).

## Adaptive difficulty (his Math Level, 1.0–10.0)
The alert script keeps his Math Level from his answers: +0.18 for a right answer within 90 seconds, +0.12 for a slower right answer, −0.3 for a miss. He starts at 3.0, so it rises slowly and drops back faster. Read the latest level from the newest Math Blitz email in Len's inbox (Gmail connector) (the `[blitz-state … level=X.X …]` line). Write the day's question at that level:
- **1–3 Warm-up:** one step at a time, small whole numbers, explain every move.
- **3–5 Algebra 1:** two or three steps, negatives and fractions allowed, short word problems.
- **5–6.5 SAT Foundations:** real SAT wording, one twist (a trap answer that's the right number to the wrong question).
- **6.5–8 SAT Medium:** multi-step, combine two ideas, units or context to decode.
- **8–9.5 SAT Hard:** the hardest-question patterns: parameters (constants like k), "no solution" or "infinitely many", equivalent forms, Desmos-solvable shortcuts.
- **9.5–10 1600 Mode:** SAT's toughest module-2 style; finish in under 90 seconds.
Pace through the topic list by results: advance one topic per correct day; on a miss do an Instant Replay of the same topic one level easier; three right in a row at Level 7 or higher lets you skip a topic he clearly already knows (note it in the progress file).

## Free resources (link only, never copy their content)
- Every lesson gets a ⭐ Bonus Quest: a Khan Academy practice link for that exact topic, using the search URL `https://www.khanacademy.org/search?page_search_query=<topic words>` (it lists the matching exercise first).
- Below SAT Foundations (level < 5): also link Khan's free "Get Ready for SAT Prep: Math" course (for students starting early). From level 5 up: Khan's Digital SAT Math course at `https://www.khanacademy.org/digital-sat`.
- Add Desmos (`https://www.desmos.com/calculator`) whenever graphing or checking a solution helps. It's the calculator built into the real SAT.
- About every 4 weeks, once Level ≥ 6: a "Mega Boss" quest to take a free full-length practice test in the College Board's Bluebook app (`https://satsuite.collegeboard.org/practice/practice-tests/bluebook`). He needs a free College Board account.
- Hard-mode extra for Level ≥ 8: Art of Problem Solving's free Alcumus (`https://artofproblemsolving.com/alcumus`).

## Unit 1 — Algebra foundations (SAT: Algebra)
1. Two-step equations: the Balance Trick
2. Equations with variables on both sides
3. Distributing and combining like terms
4. Equations with fractions: clear the denominators
5. Negative numbers in equations (sign traps)
6. Turning word problems into equations
8. Inequalities: solving, and flipping the sign
9. Inequalities in word problems ("at least", "no more than")
10. Absolute value equations
11. Literal equations: solve for a letter (rearranging formulas)
12. Ratios and proportions (cross-multiply)
13. Percents: part, whole, percent
15. Percent increase and decrease
16. Unit rates and unit conversion
17. Slope from two points
18. Slope-intercept form y = mx + b
19. Writing a line from a word problem (rate + starting value)
20. Graphing lines and reading intercepts
22. Point-slope and standard form; converting
23. Parallel and perpendicular lines
24. Linear models: what slope and intercept mean in context
25. Systems of equations: substitution
26. Systems: elimination
27. Systems in word problems
29. Systems with no solution / infinitely many (SAT favorite)
30. Systems of inequalities and graphs
31. Linear functions and f(x) notation

## Unit 2 — Exponents, roots and polynomials (SAT: Advanced Math)
32. Exponent rules (product, quotient, power)
33. Zero and negative exponents
34. Fractional exponents and radicals
36. Simplifying square roots
37. Adding and multiplying polynomials
38. FOIL and special products (a+b)², (a−b)(a+b)
39. Factoring out the GCF
40. Factoring x² + bx + c
41. Factoring ax² + bx + c
43. Difference of squares and perfect squares
44. Solving quadratics by factoring
45. Square-root method and completing the square
46. The quadratic formula
47. The discriminant: how many solutions?
48. Vertex form and the vertex of a parabola
50. Parabolas: zeros, vertex, axis of symmetry from a graph
51. Sum and product of roots (SAT shortcut)
52. Quadratic word problems (projectiles, area)
53. Linear–quadratic systems
54. Function notation, composition f(g(x))
55. Domain and range
57. Transformations of graphs (shifts, stretches, reflections)
58. Exponential growth and decay
59. Linear vs exponential models
60. Compound interest and percent-per-period models
61. Rational expressions: simplify, multiply, divide
62. Rational equations (watch for extraneous answers)
64. Radical equations (and extraneous answers)
65. Polynomial division and the remainder theorem
66. Zeros and factors of polynomials; reading polynomial graphs
67. Equivalent expressions (SAT "which is equivalent")
68. Isolating a quantity in a complex formula

## Unit 3 — Problem solving and data (SAT: Problem-Solving & Data Analysis)
69. Mean, median, mode, range
71. How outliers change mean vs median
72. Standard deviation (the idea, no formula)
73. Reading bar graphs, histograms, dot plots
74. Box plots
75. Scatterplots and lines of best fit
76. Using a best-fit line to predict
78. Two-way tables
79. Probability basics
80. Conditional probability from tables
81. Sampling, bias, and what a survey can conclude
82. Margin of error and confidence
83. Observational studies vs experiments (cause vs correlation)
85. Multi-step percent problems (tax, tip, discount stacking)
86. Rates and work problems
87. Density and unit conversion with squares/cubes

## Unit 4 — Geometry and trigonometry (SAT: Geometry & Trigonometry)
88. Angles: vertical, supplementary, parallel lines
89. Triangle angle sum and exterior angles
90. Area and perimeter of polygons
92. Pythagorean theorem
93. Special right triangles 30-60-90 and 45-45-90
94. Similar triangles
95. Volume and surface area (prisms, cylinders, cones, spheres)
96. Circles: area, circumference
97. Arc length and sector area
99. Radians
100. Equation of a circle; completing the square for circles
101. SOH-CAH-TOA
102. sin x = cos(90° − x) (SAT favorite)
103. The unit circle basics
104. Inscribed angles and tangent lines
106. Scaling: what happens to area and volume when lengths change
107. Complex numbers (i, adding, multiplying)

## Unit 5 — SAT speed and strategy (all domains)
108. Plugging in numbers
109. Backsolving from the answer choices
110. Desmos tricks for systems and quadratics
111. Reading long word problems fast
113. Hardest-question patterns: Algebra
114. Hardest-question patterns: Advanced Math
115. Hardest-question patterns: Data
116. Hardest-question patterns: Geometry & Trig
117. Grid-in (student-produced response) tips
After day 117: rotate through the hardest-question patterns from every unit, weighting the topics he has missed most.
