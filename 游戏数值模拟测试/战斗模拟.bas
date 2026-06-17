Attribute VB_Name = "CombatSimulation"
Option Explicit

' ============================================
' 游戏数值战斗模拟系统
' 模拟 3 个职业的 1v1 PvP 战斗
' ============================================

' 角色数据结构
Public Type Character
    Name As String      ' 职业名称
    HP As Double        ' 当前生命值
    MaxHP As Double     ' 最大生命值
    ATK As Double       ' 攻击力
    DEF As Double       ' 防御力
    SPD As Double       ' 速度
    CRIT As Double      ' 暴击率 (0-1)
    CRIT_DMG As Double  ' 暴击伤害倍率
    Skill1Name As String
    Skill1Mult As Double
    Skill1CD As Integer
    Skill1CurrentCD As Integer
    Skill2Name As String
    Skill2Mult As Double
    Skill2CD As Integer
    Skill2CurrentCD As Integer
End Type

' ============================================
' 主函数:运行所有对战模拟
' ============================================
Public Sub RunAllSimulations()
    Dim ws As Worksheet
    Dim fighter As Character, mage As Character, assassin As Character
    
    ' 读取职业数据
    Call ReadCharacterStats(fighter, "战士")
    Call ReadCharacterStats(mage, "法师")
    Call ReadCharacterStats(assassin, "刺客")
    
    ' 创建或清空结果表
    On Error Resume Next
    Set ws = ThisWorkbook.Sheets("模拟结果")
    On Error GoTo 0
    
    If ws Is Nothing Then
        Set ws = ThisWorkbook.Sheets.Add(After:=ThisWorkbook.Sheets(ThisWorkbook.Sheets.Count))
        ws.Name = "模拟结果"
    Else
        ws.Cells.Clear
    End If
    
    ' 写入表头
    ws.Cells(1, 1).Value = "对战"
    ws.Cells(1, 2).Value = "总场次"
    ws.Cells(1, 3).Value = "A胜场"
    ws.Cells(1, 4).Value = "B胜场"
    ws.Cells(1, 5).Value = "A胜率"
    ws.Cells(1, 6).Value = "B胜率"
    ws.Cells(1, 7).Value = "平均回合数"
    ws.Cells(1, 8).Value = "平衡性评价"
    
    ' 表头格式
    ws.Range("A1:H1").Font.Bold = True
    ws.Range("A1:H1").Interior.Color = RGB(68, 114, 196)
    ws.Range("A1:H1").Font.Color = RGB(255, 255, 255)
    
    Dim rowNum As Integer
    rowNum = 2
    
    ' 模拟三组对战
    Dim results As Variant
    
    ' 1. 战士 vs 法师
    results = SimulateBattle(fighter, mage, 1000)
    Call WriteResult(ws, rowNum, "战士 vs 法师", 1000, results)
    rowNum = rowNum + 1
    
    ' 2. 战士 vs 刺客
    results = SimulateBattle(fighter, assassin, 1000)
    Call WriteResult(ws, rowNum, "战士 vs 刺客", 1000, results)
    rowNum = rowNum + 1
    
    ' 3. 法师 vs 刺客
    results = SimulateBattle(mage, assassin, 1000)
    Call WriteResult(ws, rowNum, "法师 vs 刺客", 1000, results)
    rowNum = rowNum + 1
    
    ' 自动调整列宽
    ws.Columns("A:H").AutoFit
    
    ' 添加详细统计
    rowNum = rowNum + 2
    ws.Cells(rowNum, 1).Value = "详细统计"
    ws.Cells(rowNum, 1).Font.Bold = True
    ws.Cells(rowNum, 1).Font.Size = 14
    rowNum = rowNum + 1
    
    ws.Cells(rowNum, 1).Value = "对战"
    ws.Cells(rowNum, 2).Value = "最短回合"
    ws.Cells(rowNum, 3).Value = "最长回合"
    ws.Cells(rowNum, 4).Value = "A最高伤害"
    ws.Cells(rowNum, 5).Value = "B最高伤害"
    ws.Cells(rowNum, 6).Value = "A暴击次数"
    ws.Cells(rowNum, 7).Value = "B暴击次数"
    ws.Range(ws.Cells(rowNum, 1), ws.Cells(rowNum, 7)).Font.Bold = True
    ws.Range(ws.Cells(rowNum, 1), ws.Cells(rowNum, 7)).Interior.Color = RGB(68, 114, 196)
    ws.Range(ws.Cells(rowNum, 1), ws.Cells(rowNum, 7)).Font.Color = RGB(255, 255, 255)
    rowNum = rowNum + 1
    
    ' 详细统计 - 战士 vs 法师
    Call WriteDetailResult(ws, rowNum, "战士 vs 法师", fighter, mage)
    rowNum = rowNum + 1
    
    ' 详细统计 - 战士 vs 刺客
    Call WriteDetailResult(ws, rowNum, "战士 vs 刺客", fighter, assassin)
    rowNum = rowNum + 1
    
    ' 详细统计 - 法师 vs 刺客
    Call WriteDetailResult(ws, rowNum, "法师 vs 刺客", mage, assassin)
    
    ws.Columns("A:G").AutoFit
    
    MsgBox "模拟完成!请查看'模拟结果'工作表。", vbInformation, "战斗模拟"
End Sub

' ============================================
' 从Excel读取职业数据
' ============================================
Private Sub ReadCharacterStats(ByRef char As Character, ByVal charName As String)
    Dim ws As Worksheet
    Set ws = ThisWorkbook.Sheets("玩家数值")
    
    Dim i As Integer
    For i = 2 To 4
        If ws.Cells(i, 1).Value = charName Then
            char.Name = ws.Cells(i, 1).Value
            char.MaxHP = ws.Cells(i, 2).Value
            char.HP = char.MaxHP
            char.ATK = ws.Cells(i, 3).Value
            char.DEF = ws.Cells(i, 4).Value
            char.SPD = ws.Cells(i, 5).Value
            char.CRIT = ws.Cells(i, 6).Value
            char.CRIT_DMG = ws.Cells(i, 7).Value
            char.Skill1Name = ws.Cells(i, 10).Value
            char.Skill1Mult = ws.Cells(i, 11).Value
            char.Skill1CD = ws.Cells(i, 12).Value
            char.Skill1CurrentCD = 0
            char.Skill2Name = ws.Cells(i, 13).Value
            char.Skill2Mult = ws.Cells(i, 14).Value
            char.Skill2CD = ws.Cells(i, 15).Value
            char.Skill2CurrentCD = 0
            Exit For
        End If
    Next i
End Sub

' ============================================
' 模拟多场战斗
' 返回: Array(A胜场, B胜场, 总回合数, 最短回合, 最长回合, A最高伤害, B最高伤害, A暴击总数, B暴击总数)
' ============================================
Private Function SimulateBattle(ByRef charA As Character, ByRef charB As Character, ByVal battles As Integer) As Variant
    Dim aWins As Integer, bWins As Integer
    Dim totalRounds As Integer
    Dim minRounds As Integer, maxRounds As Integer
    Dim aMaxDmg As Double, bMaxDmg As Double
    Dim aCritCount As Long, bCritCount As Long
    
    Dim i As Integer
    For i = 1 To battles
        Dim tempA As Character, tempB As Character
        tempA = charA
        tempB = charB
        tempA.HP = tempA.MaxHP
        tempB.HP = tempB.MaxHP
        tempA.Skill1CurrentCD = 0
        tempA.Skill2CurrentCD = 0
        tempB.Skill1CurrentCD = 0
        tempB.Skill2CurrentCD = 0
        
        Dim rounds As Integer
        rounds = 0
        
        Dim aCrits As Long, bCrits As Long
        Dim aHighDmg As Double, bHighDmg As Double
        aHighDmg = 0
        bHighDmg = 0
        
        ' 战斗循环
        Do While tempA.HP > 0 And tempB.HP > 0 And rounds < 100
            rounds = rounds + 1
            
            ' 决定出手顺序
            If tempA.SPD >= tempB.SPD Then
                ' A先手
                Dim dmgA As Double
                Dim critA As Boolean
                dmgA = Attack(tempA, tempB, critA)
                If critA Then aCrits = aCrits + 1
                If dmgA > aHighDmg Then aHighDmg = dmgA
                
                If tempB.HP > 0 Then
                    Dim dmgB As Double
                    Dim critB As Boolean
                    dmgB = Attack(tempB, tempA, critB)
                    If critB Then bCrits = bCrits + 1
                    If dmgB > bHighDmg Then bHighDmg = dmgB
                End If
            Else
                ' B先手
                Dim dmgB2 As Double
                Dim critB2 As Boolean
                dmgB2 = Attack(tempB, tempA, critB2)
                If critB2 Then bCrits = bCrits + 1
                If dmgB2 > bHighDmg Then bHighDmg = dmgB2
                
                If tempA.HP > 0 Then
                    Dim dmgA2 As Double
                    Dim critA2 As Boolean
                    dmgA2 = Attack(tempA, tempB, critA2)
                    If critA2 Then aCrits = aCrits + 1
                    If dmgA2 > aHighDmg Then aHighDmg = dmgA2
                End If
            End If
            
            ' 减少CD
            If tempA.Skill1CurrentCD > 0 Then tempA.Skill1CurrentCD = tempA.Skill1CurrentCD - 1
            If tempA.Skill2CurrentCD > 0 Then tempA.Skill2CurrentCD = tempA.Skill2CurrentCD - 1
            If tempB.Skill1CurrentCD > 0 Then tempB.Skill1CurrentCD = tempB.Skill1CurrentCD - 1
            If tempB.Skill2CurrentCD > 0 Then tempB.Skill2CurrentCD = tempB.Skill2CurrentCD - 1
        Loop
        
        ' 统计结果
        totalRounds = totalRounds + rounds
        If minRounds = 0 Or rounds < minRounds Then minRounds = rounds
        If rounds > maxRounds Then maxRounds = rounds
        If aHighDmg > aMaxDmg Then aMaxDmg = aHighDmg
        If bHighDmg > bMaxDmg Then bMaxDmg = bHighDmg
        aCritCount = aCritCount + aCrits
        bCritCount = bCritCount + bCrits
        
        If tempA.HP > 0 Then
            aWins = aWins + 1
        Else
            bWins = bWins + 1
        End If
    Next i
    
    SimulateBattle = Array(aWins, bWins, totalRounds, minRounds, maxRounds, aMaxDmg, bMaxDmg, aCritCount, bCritCount)
End Function

' ============================================
' 单次攻击
' 返回伤害值, crit标记是否暴击
' ============================================
Private Function Attack(ByRef attacker As Character, ByRef defender As Character, ByRef isCrit As Boolean) As Double
    Dim baseDmg As Double
    Dim skillMult As Double
    
    ' 选择技能:优先用伤害高的技能(如果CD好了)
    skillMult = 1.0  ' 默认普攻
    isCrit = False
    
    If attacker.Skill1CurrentCD = 0 And attacker.Skill1Mult > 1.0 Then
        skillMult = attacker.Skill1Mult
        attacker.Skill1CurrentCD = attacker.Skill1CD
    ElseIf attacker.Skill2CurrentCD = 0 And attacker.Skill2Mult > 1.0 Then
        skillMult = attacker.Skill2Mult
        attacker.Skill2CurrentCD = attacker.Skill2CD
    End If
    
    ' 基础伤害
    baseDmg = attacker.ATK * skillMult
    
    ' 防御减免
    Dim defReduction As Double
    defReduction = 100 / (100 + defender.DEF)
    
    ' 暴击判定
    Dim critMult As Double
    If Rnd() < attacker.CRIT Then
        critMult = attacker.CRIT_DMG
        isCrit = True
    Else
        critMult = 1.0
    End If
    
    ' 最终伤害
    Dim finalDmg As Double
    finalDmg = baseDmg * defReduction * critMult
    
    ' 造成伤害
    defender.HP = defender.HP - finalDmg
    If defender.HP < 0 Then defender.HP = 0
    
    Attack = finalDmg
End Function

' ============================================
' 写入结果到工作表
' ============================================
Private Sub WriteResult(ws As Worksheet, ByVal row As Integer, ByVal battleName As String, ByVal total As Integer, ByRef results As Variant)
    Dim aWins As Integer, bWins As Integer
    aWins = results(0)
    bWins = results(1)
    
    ws.Cells(row, 1).Value = battleName
    ws.Cells(row, 2).Value = total
    ws.Cells(row, 3).Value = aWins
    ws.Cells(row, 4).Value = bWins
    ws.Cells(row, 5).Value = Round(aWins / total * 100, 1) & "%"
    ws.Cells(row, 6).Value = Round(bWins / total * 100, 1) & "%"
    ws.Cells(row, 7).Value = Round(results(2) / total, 1)
    
    ' 平衡性评价
    Dim aRate As Double
    aRate = aWins / total
    Dim evaluation As String
    If aRate >= 0.4 And aRate <= 0.6 Then
        evaluation = "✓ 平衡"
        ws.Cells(row, 8).Interior.Color = RGB(146, 208, 80)
    ElseIf aRate >= 0.3 And aRate <= 0.7 Then
        evaluation = "△ 轻微不平衡"
        ws.Cells(row, 8).Interior.Color = RGB(255, 192, 0)
    Else
        evaluation = "✗ 严重不平衡"
        ws.Cells(row, 8).Interior.Color = RGB(255, 0, 0)
        ws.Cells(row, 8).Font.Color = RGB(255, 255, 255)
    End If
    ws.Cells(row, 8).Value = evaluation
End Sub

' ============================================
' 写入详细统计
' ============================================
Private Sub WriteDetailResult(ws As Worksheet, ByVal row As Integer, ByVal battleName As String, ByRef charA As Character, ByRef charB As Character)
    Dim results As Variant
    results = SimulateBattle(charA, charB, 1000)
    
    ws.Cells(row, 1).Value = battleName
    ws.Cells(row, 2).Value = results(3)  ' 最短回合
    ws.Cells(row, 3).Value = results(4)  ' 最长回合
    ws.Cells(row, 4).Value = Round(results(5), 1)  ' A最高伤害
    ws.Cells(row, 5).Value = Round(results(6), 1)  ' B最高伤害
    ws.Cells(row, 6).Value = results(7)  ' A暴击次数
    ws.Cells(row, 7).Value = results(8)  ' B暴击次数
End Sub
