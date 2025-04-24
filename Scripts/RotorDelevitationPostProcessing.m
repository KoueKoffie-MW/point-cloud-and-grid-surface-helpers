% Rotor Delevitation Post processing

plot([out.recordout1{1}.Values.Data' -6.5 -6.5 6.5 6.5]',[out.recordout1{2}.Values.Data' -6.5 6.5 6.5 -6.5]')
hold on
plot([out.recordout2{1}.Values.Data' -6.5 -6.5 6.5 6.5]',[out.recordout2{2}.Values.Data' -6.5 6.5 6.5 -6.5]')

comet([out.recordout1{1}.Values.Data' -5.5 -5.5 5.5 5.5]',[out.recordout1{2}.Values.Data' -5.5 5.5 5.5 -5.5]')
comet([out.recordout2{1}.Values.Data' -5.5 -5.5 5.5 5.5]',[out.recordout2{2}.Values.Data' -5.5 5.5 5.5 -5.5]')