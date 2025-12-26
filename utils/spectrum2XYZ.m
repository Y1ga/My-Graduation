function [XYZ,coor]=spectrum2XYZ(start_col,end_col,file_name,ill_name)

    %reading the color matching functions  
    ciexyz31_1=csvread('ciexyz31_1.csv');
    wl_CMF=ciexyz31_1(:,1);
    redCMF=ciexyz31_1(:,2);
    greenCMF=ciexyz31_1 (:,3);
    blueCMF=ciexyz31_1(:,4);

    %reading the illuminant spectrum
    ill=table2array(readtable((ill_name)));       %D65 light source
    wl_SC=ill(:,1);
    source=ill(:,2);

    %reading the reflectance spectrum,
    %format: first column,wavelength ;second.column reflectance spectrum
    RS=table2array(readtable((file_name)));

    %get wavelength
    wl_RS=RS(2:end,1);          
    if(wl_RS<10e-6)          %convert to nm if it its unit is m
        wl_RS=wl_RS.*10^9;
    end
    if(wl_RS>10e-6) & (wl_RS<10e-3)          %convert to nm if it its unit is mm
        wl_RS=wl_RS.*10^6;
    end
    if(wl_RS>10e-3) & (wl_RS<1)          %convert to nm if it its unit is um
        wl_RS=wl_RS.*10^3;
    end

    rf=RS(2:end,start_col:end_col);         %get all column

    % wavelength 1 nm interval
    wl=(400:700)'; %nm

    %interp all wavelength
    rf_new=interp1(wl_RS,rf,wl,'makima');
    source_new=interp1(wl_SC,source,wl,'makima');
    redCMF_new=interp1(wl_CMF,redCMF,wl,'makima');
    greenCMF_new=interp1(wl_CMF,greenCMF,wl,'makima');
    blueCMF_new=interp1(wl_CMF,blueCMF,wl,'makima');

    k=100/sum(source_new.*greenCMF_new);  % calculate k

    num=length(rf(1,:));    %number of reflectance spectrums

    %initialize XYZ CIE 1931
    XYZ=zeros(num,3);
    XX=zeros(num,1);
    YY=zeros(num,1);
    ZZ=zeros(num,1);
    for i=1:num
        XX(i)=k*sum(source_new.*redCMF_new.*rf_new(:,i)); % calculate X
        YY(i)=k*sum(source_new.*greenCMF_new.*rf_new(:,i)); % calculate Y
        ZZ(i)=k*sum(source_new.*blueCMF_new.*rf_new(:,i)); % ¼ÆËãZ´Ì¼¤Öµ
        XYZ(i,:)=[XX(i),YY(i),ZZ(i)];
    end
    XYZ=XYZ/100;
    %chromaticity coordinate  x y z 
    s=XX+YY+ZZ;
    x=XX./s; 
    y=YY./s;
    z=ZZ./s;
    coor=[x,y];
end