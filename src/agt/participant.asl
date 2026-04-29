+cfp(Servico)[source(Iniciador)] 
   <- .print("Recebi um aviso de obra de ", Iniciador, " para ", Servico);
      !calcular_orcamento(Servico, Iniciador).

+!calcular_orcamento(Servico, Iniciador) 
   <-
      .random(R);
      Preco = math.round(R * 100) + 50; 
      
      .print("Fiz os calculos. Vou cobrar R$ ", Preco, " pela pintura.");
      
      .send(Iniciador, tell, propose(Servico, Preco)).