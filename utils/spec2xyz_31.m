function [XYZ, xyz] = spec2xyz_31(spec)
    ciexyz31_1=load_mat("ciexyz31_1","gt");
    ill = load_mat("ill_D65", "gt");
    redCMF=ciexyz31_1(:,2);
    greenCMF=ciexyz31_1 (:,3);
    blueCMF=ciexyz31_1(:,4);
    source=ill(:,2);
    
    wl_RS=(400:10:700)'; 
    rf = spec;
    wl=(400:700)'; %nm
    
    %interp all wavelength
    rf_new=interp1(wl_RS,rf,wl,'makima');   
    k=100/sum(source.*greenCMF);  % calculate k

    num=size(rf(1,:),1);    %number of reflectance spectrums
    XYZ=zeros(num,3);
    XX=zeros(num,1);
    YY=zeros(num,1);
    ZZ=zeros(num,1);
    parfor i=1:num
        XX(i)=k*sum(source.*redCMF.*rf_new(:,i)); % calculate X
        YY(i)=k*sum(source.*greenCMF.*rf_new(:,i)); % calculate Y
        ZZ(i)=k*sum(source.*blueCMF.*rf_new(:,i)); % ¼ÆËãZ´Ì¼¤Öµ
        XYZ(i,:)=[XX(i),YY(i),ZZ(i)];
    end
    XYZ = XYZ / 100;
    s=XX+YY+ZZ;
    x=XX./s; 
    y=YY./s;
    z=ZZ./s;
    xyz = [x,y,z];
end
