%Similarity measurement and system identification
clear;
load ("./data/batch_norm_data.mat");
T_predicts=[];
Y_predicts=[];
Y_actuals=[];
qBatch= 5;                      %Query Batch
qTime= 101;                      %Query Time
size_Profile=30;                %Query Profile size
forward_Profile=10;
Ts= 1;                          %Delta Time
prediction_time= 10;                 %Time after qPoint to be predicted
    
for itr=1:30 
    qTime=35+5*itr;
    i_qTime=qTime-size_Profile+1;   %Initial query profile time
    qProfile= Data(i_qTime:qTime,:,qBatch); %Query Profile
    

    cProfile= qProfile;             %Combined Profile
    wProfiles=[];
    sProfiles=[];
    for b=1:qBatch-1
        tProfile= Data(:,:,b);
        [rProfile,totalCost,iTime]= TWED(qProfile,tProfile);
        rProfile= Data(iTime:iTime+size_Profile+forward_Profile,:,b);
        sProfiles(:,:,b)= rProfile;
        W=[];
        for i=1:size_Profile
            dt= abs(iTime-i_qTime);
            db= abs(b-qBatch);
            ds= sqrt(sum((qProfile(i,:) - rProfile(i,:)) .^ 2));

            W(i,:)=[exp(-ds*ds),exp(-0.001*dt*dt),exp(-0.1*db*db)];
        end
        for i=size_Profile+1:size_Profile+forward_Profile
            dt= abs(iTime-i_qTime);
            db= abs(b-qBatch);
            ds=0;
            
            W(i,:)=[exp(-ds*ds),exp(-0.001*dt*dt),exp(-0.1*db*db)];
        end
        wProfiles(:,:,b)= W;
    end

    %Softmax Implementation
    for i=1:3
        wProfiles(:,i,:)= wProfiles(:,i,:)/sum(sum(wProfiles(:,i,:)));
    end

    cProfile= qProfile;             %Combined Profile
    for i=1:size_Profile+forward_Profile
        temp=0;
        temp2=0;
        for b=1:qBatch-1
            w=wProfiles(i,1,b)*wProfiles(i,2,b)*wProfiles(i,3,b);
            temp=temp+sProfiles(i,:,b)*w;
            temp2=temp2+w;
        end
        cProfile(i,:)=temp/temp2;
    end
    
    input=[1,2];
    output=[4];
    U= cProfile(:,input);  %Inputs
    Y= cProfile(:,output);      %Outputs

    data = iddata(Y,U,Ts);
    
    [sys,x0] = ssest(data,1);

    t = 0:Ts:Ts*(size_Profile-1)+Ts*prediction_time;
    uq= Data(i_qTime:qTime+prediction_time,input,qBatch);
    yq= Data(i_qTime:qTime+prediction_time,output,qBatch);
    [y,x] = lsim(sys,uq',t,x0);
    lastPoint= size_Profile +prediction_time;
    T_predicts(itr)= qTime+prediction_time;
    compareOut=1;
    Y_predicts(itr)= y(lastPoint,compareOut);
    Y_actuals(itr)= yq(lastPoint,compareOut);
    plot(t,y);
    hold on;
    plot(t,yq);
end
hold off;
scatter(T_predicts,Y_predicts);
hold on;
line(T_predicts,Y_predicts);
scatter(T_predicts,Y_actuals);
line(T_predicts,Y_actuals);
legend('Predicted','Predicted','Actual','Actual')
xlabel('Time') 
ylabel('Conversion')
err = immse(Y_actuals,Y_predicts)