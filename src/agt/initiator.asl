!iniciar_leilao.

+!iniciar_leilao 
   <- .print("Preciso de alguem para pintar_parede");
      // Envia mensagem para todos agentes ativos
      .broadcast(tell, cfp(pintar_parede)).

+propose(Servico, Preco)[source(Participante)] 
   <- .print("Recebi proposta do ", Participante, ": R$ ", Preco, " para o servico de ", Servico).