local _, Engine = ...

local L = Engine:NewLocale("ptBR")
if not L then return end

---------------------------------------------------------------------
-- System Messages
---------------------------------------------------------------------

-- Core Engine
L["Bad argument #%d to '%s': %s expected, got %s"] = "Argumento incorreto #%d para '%s': %s esperado, obtido %s"
L["The Engine has no method named '%s'!"] = "O mecanismo não tem nenhum método chamado '%s'!"
L["The handler '%s' has no method named '%s'!"] = "O manipulador '%s' não tem nenhum método chamado '%s'!"
L["The handler element '%s' has no method named '%s'!"] = "O elemento manipulador '%s' não tem nenhum método chamado '%s'!"
L["The module '%s' has no method named '%s'!"] = "O módulo '%s' não tem nenhum método chamado '%s'!"
L["The module widget '%s' has no method named '%s'!"] = "O widget de módulo '%s' não tem nenhum método chamado '%s'!"
L["The Engine has no method named '%s'!"] = "O mecanismo não tem nenhum método chamado '%s'!"
L["The handler '%s' has no method named '%s'!"] = "O manipulador '%s' não tem nenhum método chamado '%s'!"
L["The module '%s' has no method named '%s'!"] = "O módulo '%s' não tem nenhum método chamado '%s'!"
L["The event '%s' isn't currently registered to any object."] = "O evento '%s' não está registrado em nenhum objeto."
L["The event '%s' isn't currently registered to the object '%s'."] = "O evento '%s' não está registrado no objeto '%s'."
L["Attempting to unregister the general occurence of the event '%s' in the object '%s', when no such thing has been registered. Did you forget to add function or method name to UnregisterEvent?"] = "Tentativa de cancelar o registro da ocorrência geral do evento '%s' no objeto '%s', quando nenhuma dessas coisas foi registrada. Você se esqueceu de adicionar nome de função ou método para UnregisterEvent?"
L["The method named '%s' isn't registered for the event '%s' in the object '%s'."] = "O método chamado '%s' não está registrado para o evento '%s' no objeto '%s'."
L["The function call assigned to the event '%s' in the object '%s' doesn't exist."] = "A chamada de função atribuída ao evento '%s' no objeto '%s' não existe."
L["The message '%s' isn't currently registered to any object."] = "A mensagem '%s' não está registrada em nenhum objeto."
L["The message '%s' isn't currently registered to the object '%s'."] = "A mensagem '%s' não está atualmente registrada no objeto '%s'."
L["Attempting to unregister the general occurence of the message '%s' in the object '%s', when no such thing has been registered. Did you forget to add function or method name to UnregisterMessage?"] = "Tentativa de cancelar o registro da ocorrência geral da mensagem '%s' no objeto '%s', quando nenhuma dessas coisas foi registrada. Você se esqueceu de adicionar nome de função ou método para UnregisterMessage?"
L["The method named '%s' isn't registered for the message '%s' in the object '%s'."] = "O método chamado '%s' não está registrado para a mensagem '%s' no objeto '%s'."
L["The function call assigned to the message '%s' in the object '%s' doesn't exist."] = "A chamada de função atribuída à mensagem '%s' no objeto '%s' não existe."
L["The config '%s' already exists!"] = "A configuração '%s' já existe!"
L["The config '%s' doesn't exist!"] = "A configuração '%s' não existe!"
L["The config '%s' doesn't have a profile named '%s'!"] = "A configuração '%s' não tem um perfil chamado '%s'!"
L["The static config '%s' doesn't exist!"] = "A configuração estática '%s' não existe!"
L["The static config '%s' already exists!"] = "A configuração estática '%s' já existe!"
L["Bad argument #%d to '%s': No handler named '%s' exist!"] = "Argumento incorreto #%d para '%s': Nenhum manipulador chamado '%s' existe!"
L["Bad argument #%d to '%s': No module named '%s' exist!"] = "Argumento incorreto #%d para '%s': Nenhum módulo com o nome '%s' existe!"
L["The element '%s' is already registered to the '%s' handler!"] = "O elemento '%s' já está registrado para o manipulador '%s'!"
L["The widget '%s' is already registered to the '%s' module!"] = "O widget '%s' já está registrado no módulo '%s'!"
L["A handler named '%s' is already registered!"] = "Um manipulador chamado '%s' já está registrado!"
L["Bad argument #%d to '%s': The name '%s' is reserved for a handler!"] = "Argumento incorreto #%d para '%s': O nome '%s' está reservado para um manipulador!"
L["Bad argument #%d to '%s': A module named '%s' already exists!"] = "Argumento incorreto #%d para '%s': Um módulo com o nome '%s' já existe!"
L["Bad argument #%d to '%s': The load priority '%s' is invalid! Valid priorities are: %s"] = "Argumento incorreto #%d para '%s': A prioridade de carga '%s' é inválida! As prioridades válidas são:%s"
L["Attention!"] = "Atenção!"
L["The UI scale is wrong, so the graphics might appear fuzzy or pixelated. If you choose to ignore it, you won't be asked about this issue again.|n|nFix this issue now?"] = "A escala da IU está errada, portanto, os gráficos podem parecer difusos ou pixelados. Se você optar por ignorá-lo, você não será questionado sobre esse problema novamente.|n|nFixar este problema agora?"
L["UI scaling is activated and needs to be disabled, otherwise you'll might get fuzzy borders or pixelated graphics. If you choose to ignore it and handle the UI scaling yourself, you won't be asked about this issue again.|n|nFix this issue now?"] = "A escala de IU está ativada e precisa ser desativada, caso contrário, você poderá obter bordas fuzzy ou gráficos pixelados. Se você optar por ignorá-lo e lidar com a escala de IU, você não será questionado sobre esse problema novamente.|n|nFixar este problema agora?"
L["UI scaling was turned off but needs to be enabled, otherwise you'll might get fuzzy borders or pixelated graphics. If you choose to ignore it and handle the UI scaling yourself, you won't be asked about this issue again.|n|nFix this issue now?"] = "A escala da IU estava desativada, mas precisa ser ativada, caso contrário, você poderá obter bordas distorcidas ou gráficos pixelados. Se você optar por ignorá-lo e lidar com a escala da IU, não será questionado sobre esse problema novamente.|n|nFixar este problema agora?"
L["The UI scale is wrong, so the graphics might appear fuzzy or pixelated. If you choose to ignore it and handle the UI scaling yourself, you won't be asked about this issue again.|n|nFix this issue now?"] = "A escala da interface do usuário está errada, portanto, os gráficos podem parecer difusos ou pixelados.Se você optar por ignorá-lo e lidar com a escala da IU você mesmo, você não será perguntado sobre este problema novamente.|n|nFixar este problema agora?"
L["Your resolution is too low for this UI, but the UI scale can still be adjusted to make it fit. If you choose to ignore it and handle the UI scaling yourself, you won't be asked about this issue again.|n|nFix this issue now?"] = "Sua resolução é muito baixa para essa interface do usuário, mas a escala da interface do usuário ainda pode ser ajustada para torná-la adequada. Se você optar por ignorá-lo e lidar com a escala da IU você mesmo, não será perguntado sobre este problema novamente.|n|nFixar este problema agora?"
L["Accept"] = "Aceitar"
L["Cancel"] = "Cancelar"
L["Ignore"] = "Ignorar"
L["You can re-enable the auto scaling by typing |cff448800/diabolic autoscale|r in the chat at any time."] = "Você pode reativar a escala automática digitando |cff448800/diabolic autoscale|r no chat a qualquer momento."
L["Auto scaling of the UI has been enabled."] = "Escala automático para a IU foi ativado."
L["Auto scaling of the UI has been disabled."] = "Escala automático para a IU foi desativado."
L["Reload Needed"] = "Precisa dar Reload"
L["The user interface has to be reloaded for the changes to be applied.|n|nDo you wish to do this now?"] = "A interface do usuário precisa ser recarregada para que as alterações sejam aplicadas.|n|n Você deseja fazer isso agora?"
L["The Engine can't be tampered with!"] = "O Motor não pode ser adulterado!"

-- Blizzard Handler
L["Bad argument #%d to '%s'. No object named '%s' exists."] = "Argumento incorreto #%d para '%s'. Nenhum objeto com o nome '%s' existe."


---------------------------------------------------------------------
-- User Interface
---------------------------------------------------------------------


-- actionbar module
---------------------------------------------------------------------
-- button tooltips
L["Main Menu"] = "Menu Principal"
L["<Left-click> to toggle menu."] = "<Clique com o botão esquerdo do mouse> para mostrar o menu."
L["Action Bars"] = "Barras de Ação"
L["<Left-click> to toggle action bar menu."] = "<Clique com o botão esquerdo do mouse> para mostrar o menu da barra de ação."
L["Bags"] = "Bolsas"
L["<Left-click> to toggle bags."] = "<Clique com o botão esquerdo do mouse> para mostrar o inventário."
L["<Right-click> to toggle bag bar."] = "<Botão direito do mouse> para mostrar a barra de bolsas."
L["Chat"] = "Chat"
L["<Left-click> or <Enter> to chat."] = "<Clique com o botão esquerdo do mouse> ou <Enter> para conversar."
L["Friends & Guild"] = "Amigos & Guilda"
L["<Left-click> to toggle social frames."] = "<Clique com o botão esquerdo do mouse> para mostrar os quadros sociais."

-- actionbar menu
--L["Action Bars"] = "Barras de Ação"
L["Side Bars"] = "Barras laterais"
L["Hold |cff00b200<Alt+Ctrl+Shift>|r and drag to remove spells, macros and items from the action buttons."] = "Segure |cff00b200<Alt+Ctrl+Shift>|r e arraste para remover feitiços, macros e itens dos botões de ação."
L["No Bars"] = "Sem barras"
L["One"] = "Uma"
L["Two"] = "Duas"
L["Three"] = "Três"

-- xp bar
L["Current XP: "] = "XP Atual: "
L["Rested Bonus: "] = "Bônus de Descanso: "
L["Rested"] = "Descansado"
L["%s of normal experience\ngained from monsters."] = "%s da experiencia normal\nganha de inimigos"
L["Resting"] = "Descansando"
L["You must rest for %s additional\nhours to become fully rested."] = "Você deve descansar por%s adicionais\nhoras para ficar totalmente descansado."
L["You must rest for %s additional\nminutes to become fully rested."] = "Você deve descansar por%s adicionais\nminutos para ficar totalmente descansado."
L["Normal"] = "Normal"
L["You should rest at an Inn."] = "Você deveria descançar em uma pousada."

-- stance bar
L["Stances"] = "Posições"
L["<Left-click> to toggle stance bar."] = "<Clique com o botão esquerdo do mouse> para mostrar a barra de posição."

-- added to the interface options menu in WotLK
-- Not too acurate this translation, I don't know exactly what you are talking about.
L["Cast action keybinds on key down"] = "Ação de cast da lista de teclas na tecla abaixo"


-- chat module
---------------------------------------------------------------------
L["Chat Setup"] = "Configuração do chat"
L["Would you like to automatically have the main chat window sized and positioned to match Diablo III, or would you like to manually handle this yourself?|n|nIf you choose to manually position things yourself, you won't be asked about this issue again."] = "Gostaria de ter automaticamente a janela de chat principal dimensionados e posicionados para coincidir com Diablo III, ou você gostaria de lidar manualmente por você mesmo?|n|nSe escolher posicionar manualmente, você não será questionado novamente sobre isso."
L["Auto"] = "Automático"
L["Manual"] = "Manual"
L["You can re-enable the auto positioning by typing |cff448800/diabolic autoposition|r in the chat at any time."] = ""Você pode reativar o posicionamento automático digitando |cff448800/diabolic autoposition|r no chat a qualquer momento."
L["Auto positioning of chat windows has been enabled."] = "O posicionamento automático das janelas de chat foi ativado."
L["Auto positioning of chat windows has been disabled."] = "O posicionamento automático das janelas de chat foi desativado."


-- minimap module
---------------------------------------------------------------------
L["<Left-click> to toggle calendar."] = "<Clique com o botão esquerdo do mouse> para mostrar o calendário."
L["<Middle-click> to toggle stopwatch."] = "<Clicar no meio do mouse> para mostrar o cronômetro."
L["<Right-click> to configure clock."] = "<Clique com o botão direito do mouse> para configurar o relógio."


-- tooltips
-- Don't need translation
---------------------------------------------------------------------
L["BoA"] = true
L["PvP"] = true
L["SpellID:"] = true
L["Caster:"] = true


-- unitframe module
---------------------------------------------------------------------



-- abbreviations
-- Don't need translation
---------------------------------------------------------------------
L["d"] = true -- abbreviation for "days" when showing time
L["h"] = true -- abbreviation for "hours" when showing time
L["m"] = true -- abbreviation for "minutes" when showing time
L["s"] = true -- abbreviation for "seconds" when showing time
